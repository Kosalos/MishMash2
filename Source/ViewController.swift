import UIKit
import Metal
import MetalKit
import simd

var control = Control()
var vc:ViewController! = nil

let view3D = View3D()
var is3D:Bool = false

let varisNames = [ "Linear", "Sinusoidal", "Spherical", "Swirl", "Horseshoe", "Polar",
                   "Hankerchief", "Heart", "Disc", "Spiral", "Hyperbolic", "Diamond", "Ex",
                   "Julia", "JuliaN", "Bent", "Waves", "Fisheye", "Popcorn", "Power", "Rings", "Fan",
                   "Eyefish", "Bubble", "Cylinder", "Tangent", "Cross", "Noise", "Blur", "Square" ]

class ViewController: UIViewController, WGDelegate {
    var rendererL: Renderer!
    var rendererR: Renderer!
    var controlBuffer:MTLBuffer! = nil
    var texture1: MTLTexture!
    var texture2: MTLTexture!
    var pipeline:[MTLComputePipelineState] = []
    lazy var device: MTLDevice! = MTLCreateSystemDefaultDevice()
    lazy var commandQueue: MTLCommandQueue! = { return self.device.makeCommandQueue() }()
    var shadowFlag:Bool = false
    var hiResFlag:Bool = false
    var autoMoveFlag:Bool = false
    var isStereo:Bool = false
    
    @IBOutlet var d2View: MetalTextureView!
    @IBOutlet var d3ViewL: MTKView!
    @IBOutlet var d3ViewR: MTKView!
    @IBOutlet var wg: WidgetGroup!

    let threadGroupCount = MTLSizeMake(20,20,1)
    var threadGroups = MTLSize()
    
    //MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        vc = self
        setControlPointer(&control);

        gDevice = MTLCreateSystemDefaultDevice()
        view3D.initialize()
        d3ViewL.device = gDevice
        d3ViewR.device = gDevice
        
        guard let newRenderer = Renderer(metalKitView: d3ViewL, 0) else { fatalError("Renderer cannot be initialized") }
        rendererL = newRenderer
        rendererL.mtkView(d3ViewL, drawableSizeWillChange: d3ViewL.drawableSize)
        d3ViewL.delegate = rendererL
        
        guard let newRenderer2 = Renderer(metalKitView: d3ViewR, 1) else { fatalError("Renderer cannot be initialized") }
        rendererR = newRenderer2
        rendererR.mtkView(d3ViewR, drawableSizeWillChange: d3ViewR.drawableSize)
        d3ViewR.delegate = rendererR
        
        func loadShader(_ name:String) -> MTLComputePipelineState {
            do {
                let defaultLibrary:MTLLibrary! = self.device.makeDefaultLibrary()
                guard let fn = defaultLibrary.makeFunction(name: name)  else { print("shader not found: " + name); exit(0) }
                return try device.makeComputePipelineState(function: fn)
            }
            catch { print("pipeline failure for : " + name); exit(0) }
        }
        
        let shaderNames = [ "fractalShader","shadowShader","heightMapShader","smoothingShader","normalShader" ]
        for i in 0 ..< shaderNames.count { pipeline.append(loadShader(shaderNames[i])) }
        
        controlBuffer = device.makeBuffer(bytes: &control, length: MemoryLayout<Control>.stride, options: MTLResourceOptions.storageModeShared)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.initRenderViews), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeWgGesture(gesture:)))
        swipeUp.direction = .up
        wg.addGestureRecognizer(swipeUp)
        
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(self.swipeWgGesture(gesture:)))
        swipeDown.direction = .down
        wg.addGestureRecognizer(swipeDown)
        
        initializeWidgetGroup()
        initRenderViews()
        setImageViewResolutionAndThreadGroups()
    }
    
    @objc func swipeWgGesture(gesture: UISwipeGestureRecognizer) -> Void {
        switch gesture.direction {
        case .up : wg.moveFocus(-1)
        case .down : wg.moveFocus(+1)
        default : break
        }
    }
    
    @IBAction func tap2Gesture(_ sender: UITapGestureRecognizer) {
        wg.isHidden = !wg.isHidden
        initRenderViews()
    }
    
    var remoteLoaded:Bool = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        wgCommand(.loadNext) // show first saved image (if any)

        if remoteLaunchOptionsLoad() { remoteLoaded = true }

        Timer.scheduledTimer(withTimeInterval:0.1, repeats:false) { timer in self.timerKickColdstart() }
    }

    @objc func timerKickColdstart() {
        if remoteLoaded { loadedData() }
        refresh()
        Timer.scheduledTimer(withTimeInterval:0.05, repeats:true) { timer in self.timerHandler() }
    }

    //MARK: -

    func initializeWidgetGroup() {
        wg.delegate = self
        wg.initialize()
        
        wg.addCommand("Edit Grammar",.grammar)
        wg.addCommand("Random",.gRandom)
        wg.addString("Gstring",1)
        
        func fGroup(_ i:Int32) {
            let pMin:Float = -3
            let pMax:Float = +3
            let pChg:Float = 0.25
            let sMin:Float = 0.1
            let sMax:Float = +4
            let sChg:Float = 0.25
            
            wg.addLine()
            wg.addColor(Int(i),Float(RowHT * 4)+4)
            wg.addDropDown(funcIndexPointer(i),varisNames)
            wg.addDualFloat(funcXtPointer(i),funcYtPointer(i),pMin,pMax,pChg,"Translate")
            wg.addDualFloat(funcXsPointer(i),funcYsPointer(i),sMin,sMax,sChg,"Scale")
            wg.addSingleFloat(funcRotPointer(i),pMin,pMax,pChg, "Rotate")
        }
        
        for i in 0 ..< 4 { fGroup(Int32(i)) }
        
        wg.addLine()
        wg.addSingleFloat(&control.multiplier, -1,1,0.1, "Multiplier")
        wg.addSingleFloat(&control.stripeDensity, -10,10,2, "Stripe")
        wg.addSingleFloat(&control.escapeRadius, 0.01,80,3, "Escape")
        wg.addSingleFloat(&control.contrast, 0.1,5,0.5, "Contrast")
        wg.addDualFloat(UnsafeMutableRawPointer(&control.R),UnsafeMutableRawPointer(&control.G), 0,1,0.15, "Color RG")
        wg.addSingleFloat(&control.B, 0,1,0.15, "Color B")
        wg.addLine()
        wg.addMove()
        wg.addLine()
        wg.addColor(10,Float(RowHT)+3);    wg.addCommand("Resolution",.resolution)
        wg.addColor(12,Float(RowHT)+3);    wg.addCommand("Shadow",.shadow)
        wg.addColor(11,Float(RowHT)+3);    wg.addCommand("Auto",.auto)
        wg.addCommand("Random",.random)
        wg.addCommand("Load Next",.loadNext)
        wg.addCommand("Save/Load",.saveLoad)
        wg.addCommand("Email",.email)
        wg.addCommand("Help",.help)
        wg.addLine()
        wg.addSingleFloat(&control.radialAngle,0,Float.pi/2,0.3, "RadialSym")
        wg.addLine()

        wg.addCommand("3D",.threeD)
        
        if is3D {
            wg.addCommand("Smooth",.smooth)
            wg.addCommand("Zoom",.zoom)
            wg.addCommand("Stereo",.stereo)
            wg.addSingleFloat(&control.height,-70,70,7, "Height")
        }
    }
    
    //MARK: -
    
    let WgWidth:CGFloat = 120
    
     @objc func initRenderViews() {
        let controlWidth = wg.isHidden ? 0 : WgWidth
        
        if !wg.isHidden { wg.frame = CGRect(x:0, y:0, width:WgWidth, height:view.bounds.height) }
        
        if !is3D {
            d2View.isHidden = false
            d3ViewL.isHidden = true
            d3ViewR.isHidden = true
            d2View.frame = CGRect(x:controlWidth, y:0, width:view.bounds.width-controlWidth, height:view.bounds.height)
        }
        else {
            d2View.isHidden = true
            d3ViewL.isHidden = false
            
            var vr = CGRect(x:controlWidth, y:0, width:view.bounds.width-controlWidth, height:view.bounds.height)
            d3ViewL.frame = vr

            if isStereo {
                vr.size.width /= 2 
                d3ViewL.frame = vr
                
                d3ViewR.isHidden = false
                vr.origin.x += vr.width
                d3ViewR.frame = vr
            }
            else {
                d3ViewR.isHidden = true
            }
            
            let hk = d3ViewL.bounds
            arcBall.initialize(Float(hk.size.width),Float(hk.size.height))            
        }
    }
    
    //MARK: -
    /*
     sending and receiving data via email
     1. launchOptions captured in AppDelegate didFinishLaunchingWithOptions()
     2. these routines just below to handle Loading data from launchOptions, and using docController to send the data
     3. edit project settings:  Target <Info> section, note the items added to "Document Types", "Imported UTIs" and "Exported UTIs"
     
     how to send:
     1.use the program as usual to display an image you like
     2.press "E" to launch airDrop popup.  Select 'Mail' icon.  Send email..
     
     how to receive:
     1. Launch the iPads built in Mail app.
     2. select the email with MishMash attachment.
     3. Tap attachment, then "Copy to MishMash2" icon
     4. fixDO:  image is loaded okay, but sometimes the app needs to be touched for force correct redraw.
     */
    
    // https://stackoverflow.com/questions/29399341/uidocumentinteractioncontroller-swift
    var fileURL:URL! = nil
    var docController:UIDocumentInteractionController!
    
    func sendEmail() {
        var fileURL:URL! = nil
        let name = "MishMash.msh"
        fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(name)
        
        do {
            control.version = Int32(versionNumber)
            let sz = MemoryLayout<Control>.size
            let data = NSData(bytes:&control, length: sz)
            try data.write(to: fileURL, options: .atomic)
        } catch { print(error); return }
        
        docController = UIDocumentInteractionController(url: fileURL)
        _ = docController.presentOptionsMenu(from: wg.frame, in:wg, animated:true)
    }
    
    func remoteLaunchOptionsLoad() -> Bool {
        if remoteLaunchOptions == nil { return false }
        
        let hk:URL = remoteLaunchOptions[UIApplicationLaunchOptionsKey.url] as! URL
        let sz = MemoryLayout<Control>.size
        let data = NSData(contentsOf:hk)
        data?.getBytes(&control, length:sz)
        
        return true
    }
    
    //MARK: -
    
    @objc func timerHandler() {
        if isBusy { return }
        var refreshNeeded:Bool = false
        
        if wg.update() { refreshNeeded = true }
        
        if autoMoveFlag {
            controlAutoMove();
            refreshNeeded = true
        }
        
        if refreshNeeded { updateImage() }
        
        if is3D {
            rotate(paceRotate.x,paceRotate.y)
        }
    }
    
    //MARK: -
    
    func refresh() { updateImage() }
    func loadedData() { updateGrammarString() }
    func focusMovement(_ pt:CGPoint) { wg.focusMovement(pt) }
    
    func randomize() {
        controlRandom()
        loadedData()
    }
    
    func grammarString() -> String {
        var chars:[UInt8] = []
        for i in 0 ..< MAX_GRAMMER { chars.append(UInt8(getGrammarCharacter(Int32(i)))) }
        chars.append(UInt8(0))
        
        return String(data:Data(chars), encoding: .utf8)!
    }
    
    func updateGrammarString() {
        updateImage()
        wg.setNeedsDisplay()
    }
    
    //MARK: -
    
    func wgRefresh() { updateImage() }
    func wgAlterPosition(_ dx:Float, _ dy:Float) { alterPosition(dx,dy) }

    func wgCommand(_ cmd:CmdIdent) {
        switch(cmd) {
        case .saveLoad : performSegue(withIdentifier: "saveLoadSegue", sender: self)
        case .help : performSegue(withIdentifier: "helpSegue", sender: self)
        case .grammar : performSegue(withIdentifier: "grammarSegue", sender: self)
        case .funcList : performSegue(withIdentifier: "widgetGroupSegue", sender:self)
            
        case .resolution :
            hiResFlag = !hiResFlag
            setImageViewResolutionAndThreadGroups()
            initRenderViews()
            refresh()
            
            if is3D {  // sometimes pan gesture is ignored. maybe because arcball?..
                let hk = d3ViewL.bounds
                arcBall.initialize(Float(hk.size.width*2),Float(hk.size.height*2))
            }

        case .gRandom :
            controlRandomGrammar()
            loadedData()

        case .auto :
            autoMoveFlag = !autoMoveFlag
            if autoMoveFlag { controlInitAutoMove() }
            
        case .shadow :
            shadowFlag = !shadowFlag
            d2View.initialize(shadowFlag ? texture2 : texture1)
            refresh()

        case .loadNext :
            let ss = SaveLoadViewController()
            ss.loadNext()
            initRenderViews()
            refresh()

        case .random :
            randomize()

        case .threeD :
            is3D = !is3D
            initRenderViews()
            initializeWidgetGroup()
            refresh()

        case .smooth :
            control.smooth += 1
            if control.smooth > 2 { control.smooth = 0 }
            refresh()

        case .zoom :
            control.zoom += 1
            if control.zoom > 2 { control.zoom = 0 }
            refresh()

        case .stereo :
            isStereo = !isStereo
            setImageViewResolutionAndThreadGroups()
            initRenderViews()
            refresh()
            
        case .email :
            sendEmail()
        }
    }
    
     func wgGetString(_ index:Int) -> String {
        switch(index) {
        case 1  : return grammarString()
        default : return "wgGetString"
        }
    }

    func wgGetColor(_ index:Int) -> UIColor {
        let c1 = UIColor(red:0.2, green:0.2, blue:0.2, alpha:1)
        let c2 = UIColor(red:0.3, green:0.2, blue:0.2, alpha:1)
        
        switch(index) {
        case 0 ... 3 : return isFunctionActive(Int32(index)) > 0 ? c2 : c1
        case 10 : return hiResFlag    ? c2 : c1
        case 11 : return autoMoveFlag ? c2 : c1
        case 12 : return shadowFlag   ? c2 : c1
        default : return .white
        }
    }
    
    func functionNameChanged() { wg.functionNameChanged() }
    
    //MARK: -
    
    func setImageViewResolutionAndThreadGroups() {
        let scale:CGFloat = hiResFlag ? 1.0 : 0.5
        control.xSize = Int32(view.bounds.size.width * scale)
        control.ySize = Int32(view.bounds.size.height * scale)
        let xsz = Int(control.xSize)
        let ysz = Int(control.ySize)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: xsz,
            height: ysz,
            mipmapped: false)
        texture1 = self.device.makeTexture(descriptor: textureDescriptor)!
        texture2 = self.device.makeTexture(descriptor: textureDescriptor)!
        
        d2View.initialize(texture1)
        
        let maxsz = max(xsz,ysz) + Int(threadGroupCount.width-1)
        threadGroups = MTLSizeMake(
            maxsz / threadGroupCount.width,
            maxsz / threadGroupCount.height,1)
    }
    
    //MARK: -
    
    func alterPosition(_ dx:Float, _ dy:Float) {
        let mx = (control.xmax - control.xmin) * dx / 500
        let my = (control.ymax - control.ymin) * dy / 500
        
        control.xmin -= mx;  control.xmax -= mx
        control.ymin -= my;  control.ymax -= my
        
        updateImage()
    }
    
    //MARK: -
    
    func alterZoomCommon(_ dz:Float) {
        let xsize = (control.xmax - control.xmin) * dz
        let ysize = (control.ymax - control.ymin) * dz
        let xc = (control.xmin + control.xmax) / 2
        let yc = (control.ymin + control.ymax) / 2
        
        control.xmin = xc - xsize;  control.xmax = xc + xsize
        control.ymin = yc - ysize;  control.ymax = yc + ysize
        
        updateImage()
    }
    
    func alterZoom(_ dz:Float) {
        alterZoomCommon(0.5 + dz / 50)
    }
    
    var pace:Int = 0
    
    func alterZoomViaPinch(_ dz:Float) {  // 0.1 ... 6.0
        pace += 1; if pace < 5 { return }
        pace = 0
        
        let amt:Float = 1 - (dz - 1.0) * 0.1
        alterZoomCommon(amt / 2)
    }
    
    //MARK: -
    
    func calcFractal() {
        control.dx = (control.xmax - control.xmin) / Float(control.xSize)
        control.dy = (control.ymax - control.ymin) / Float(control.ySize)
        controlBuffer.contents().copyMemory(from: &control, byteCount:MemoryLayout<Control>.stride)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeline[0])
        commandEncoder.setTexture(texture1, index: 0)
        commandEncoder.setBuffer(controlBuffer, offset: 0, index: 0)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        if shadowFlag { applyShadow() }
    }
    
    func applyShadow() {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeline[1])
        commandEncoder.setTexture(texture1, index: 0)
        commandEncoder.setTexture(texture2, index: 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    //MARK: -
    
    var isBusy:Bool = false
    
    func updateImage() {
        if !isBusy {
            isBusy = true
            calcFractal()
            
            if !is3D {
                d2View.display(d2View.layer)
                isBusy = false
            }
            else {
                update3DRendition()
            }
        }
    }
    
    func update3DRendition() {
        // set height and color given 2D image
        do {
            let commandBuffer = commandQueue.makeCommandBuffer()!
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
            
            commandEncoder.setComputePipelineState(pipeline[2])
            commandEncoder.setTexture(shadowFlag ? texture2 : texture1, index: 0)
            commandEncoder.setBuffer(vBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(controlBuffer, offset: 0, index: 1)
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        // apply smoothing
        if control.smooth > 0 {
            for _ in 0 ..< control.smooth {
                
                // v -> v2 ------------------------------------------
                do {
                    let commandBuffer = commandQueue.makeCommandBuffer()!
                    let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
                    commandEncoder.setComputePipelineState(pipeline[3])
                    commandEncoder.setBuffer(vBuffer,  offset: 0, index: 0)
                    commandEncoder.setBuffer(vBuffer2, offset: 0, index: 1)
                    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
                    commandEncoder.endEncoding()
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
                }
                
                // v2 -> v ------------------------------------------
                do {
                    let commandBuffer = commandQueue.makeCommandBuffer()!
                    let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
                    commandEncoder.setComputePipelineState(pipeline[3])
                    commandEncoder.setBuffer(vBuffer2, offset: 0, index: 0)
                    commandEncoder.setBuffer(vBuffer,  offset: 0, index: 1)
                    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
                    commandEncoder.endEncoding()
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
                }
            }
        }
        
        // calc vertex normals
        do {
            let commandBuffer = commandQueue.makeCommandBuffer()!
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
            
            commandEncoder.setComputePipelineState(pipeline[4])
            commandEncoder.setBuffer(vBuffer, offset: 0, index: 0)            
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        isBusy = false
    }
    
    //MARK:-
    
    var oldPt = CGPoint()
    
    @IBAction func panGesture(_ sender: UIPanGestureRecognizer) { // alter focused widget values
        var pt = sender.translation(in: self.view)
        
        switch sender.state {
        case .began :
            oldPt = pt
        case .changed :
            pt.x -= oldPt.x
            pt.y -= oldPt.y
            focusMovement(pt)
        default :
            pt.x = 0
            pt.y = 0
            focusMovement(pt)
        }
    }
    
    //MARK:-
    
    var paceRotate = CGPoint()
    
    func rotate(_ x:CGFloat, _ y:CGFloat) {
        let center = CGFloat(control.xSize / 2)
        arcBall.mouseDown(CGPoint(x: center, y: center))
        arcBall.mouseMove(CGPoint(x: center - x, y: center - y))
    }
    
    @IBAction func pan2Gesture(_ sender: UIPanGestureRecognizer) { // rotate 3D image
        let pt = sender.translation(in: self.view)
        let scale:CGFloat = 0.05
        paceRotate.x = pt.x * scale
        paceRotate.y = pt.y * scale
    }
    
    @IBAction func pinchGesture(_ sender: UIPinchGestureRecognizer) {
        let min:Float = 1       // close
        let max:Float = 1000    // far
        
        translation.z *= Float(1 + (1 - sender.scale) / 10 )
        if translation.z < min { translation.z = min }
        if translation.z > max { translation.z = max }
    }
    
    //MARK:-
    
    @IBAction func tapGesture(_ sender: UITapGestureRecognizer) {
        paceRotate.x = 0
        paceRotate.y = 0
    }
    
    override var prefersStatusBarHidden: Bool { return true }
}

// MARK:

func drawLine(_ context:CGContext, _ p1:CGPoint, _ p2:CGPoint) {
    context.beginPath()
    context.move(to:p1)
    context.addLine(to:p2)
    context.strokePath()
}

func drawVLine(_ context:CGContext, _ x:CGFloat, _ y1:CGFloat, _ y2:CGFloat) { drawLine(context,CGPoint(x:x,y:y1),CGPoint(x:x,y:y2)) }
func drawHLine(_ context:CGContext, _ x1:CGFloat, _ x2:CGFloat, _ y:CGFloat) { drawLine(context,CGPoint(x:x1, y:y),CGPoint(x: x2, y:y)) }

func drawRect(_ context:CGContext, _ r:CGRect) {
    context.beginPath()
    context.addRect(r)
    context.strokePath()
}

func drawFilledCircle(_ context:CGContext, _ center:CGPoint, _ diameter:CGFloat, _ color:CGColor) {
    context.beginPath()
    context.addEllipse(in: CGRect(x:CGFloat(center.x - diameter/2), y:CGFloat(center.y - diameter/2), width:CGFloat(diameter), height:CGFloat(diameter)))
    context.setFillColor(color)
    context.fillPath()
}

//MARK:-

var fntSize:CGFloat = 0
var txtColor:UIColor = .clear
var textFontAttributes:NSDictionary! = nil

func drawText(_ x:CGFloat, _ y:CGFloat, _ color:UIColor, _ sz:CGFloat, _ str:String) {
    if sz != fntSize || color != txtColor {
        fntSize = sz
        txtColor = color
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = NSTextAlignment.left
        let font = UIFont.init(name: "Helvetica", size:sz)!
        
        textFontAttributes = [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.foregroundColor: color,
            NSAttributedStringKey.paragraphStyle: paraStyle,
        ]
    }
    
    str.draw(in: CGRect(x:x, y:y, width:800, height:100), withAttributes: textFontAttributes as? [NSAttributedStringKey : Any])
}

