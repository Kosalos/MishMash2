import UIKit

protocol WGDelegate {
    func wgCommand(_ cmd:CmdIdent)
    func wgGetString(_ index:Int) -> String
    func wgGetColor(_ index:Int) -> UIColor
    func wgRefresh()
    func wgAlterPosition(_ dx:Float, _ dy:Float)
}

enum CmdIdent { case saveLoad,help,grammar,resolution,gRandom,auto,shadow,loadNext,random,threeD,smooth,zoom,stereo,email,funcList }
enum WgEntryKind { case singleFloat,dualFloat,dropDown,command,legend,line,string,color,move }

let NONE:Int = -1
let FontSZ:CGFloat = 16
let RowHT:CGFloat = 17.5
let GrphSZ:CGFloat = 14
let TxtYoff:CGFloat = -4
let Tab1:CGFloat = 5     // graph x1
let Tab2:CGFloat = 18    // text after graph
var py = CGFloat()

struct wgEntryData {
    var kind:WgEntryKind = .legend
    var index:Int = 0
    var cmd:CmdIdent = .help
    var str:[String] = []
    var valuePointerX:UnsafeMutableRawPointer! = nil
    var valuePointerY:UnsafeMutableRawPointer! = nil
    var deltaValue:Float = 0
    var mRange = float2()
    var fastEdit:Bool = true
    var visible:Bool = true
    var yCoord = CGFloat()
    
    func isValueWidget() ->Bool { return kind == .singleFloat || kind == .dualFloat }
    
    func getFloatValue(_ who:Int) -> Float {
        switch who {
        case 0 :
            if valuePointerX == nil { return 0 }
            return valuePointerX.load(as: Float.self)
        default:
            if valuePointerY == nil { return 0 }
            return valuePointerY.load(as: Float.self)
        }
    }
    
    func getInt32Value() -> Int {
        if valuePointerX == nil { return 0 }
        let v =  Int(valuePointerX.load(as: Int32.self))
        //Swift.print("getInt32Value = ",v.description)
        return v;
    }
    
    func valueRatio(_ who:Int) -> CGFloat {
        let den = mRange.y - mRange.x
        if den == 0 { return CGFloat(0) }
        let v = CGFloat((getFloatValue(who) - mRange.x) / den )
        if v < 0.05 { return CGFloat(0.05) }          // so graph line is always visible
        if v > 0.95 { return CGFloat(0.95) }
        return v
    }
}

class WidgetGroup: UIView {
    var delegate:WGDelegate?
    var context : CGContext?
    var data:[wgEntryData] = []
    var focus:Int = NONE
    var deltaX:Float = 0
    var deltaY:Float = 0
    
    func initialize() {
        self.backgroundColor = UIColor.black
        
        let tap2 = UITapGestureRecognizer(target: self, action: #selector(self.handleTap2(_:)))
        tap2.numberOfTapsRequired = 2
        addGestureRecognizer(tap2)
    }
    
    @objc func handleTap2(_ sender: UITapGestureRecognizer) {
        if focus != NONE {
            data[focus].fastEdit = !data[focus].fastEdit
            setNeedsDisplay()
        }
    }
    
    func wgCommand(_ cmd:CmdIdent) { delegate?.wgCommand(cmd) }
    func wgGetString(_ index:Int) -> String { return (delegate?.wgGetString(index))! }
    func wgGetColor(_ index:Int) -> UIColor { return (delegate?.wgGetColor(index))! }
    func wgRefresh() { delegate?.wgRefresh() }
    func wgAlterPosition(_ dx:Float, _ dy:Float) { delegate?.wgAlterPosition(dx,dy) }
    
    //MARK:-
    
    var dIndex:Int = 0
    
    func newEntry() {
        data.append(wgEntryData())
        dIndex = data.count-1
    }
    
    func addCommon(_ ddIndex:Int, _ min:Float, _ max:Float, _ delta:Float, _ iname:String) {
        data[ddIndex].mRange.x = min
        data[ddIndex].mRange.y = max
        data[ddIndex].deltaValue = delta
        data[ddIndex].str.append(iname)
    }
    
    func addSingleFloat(_ vx:UnsafeMutableRawPointer, _ min:Float, _ max:Float,  _ delta:Float, _ iname:String) {
        newEntry()
        data[dIndex].kind = .singleFloat
        data[dIndex].valuePointerX = vx
        addCommon(dIndex,min,max,delta,iname)
    }
    
    func addDualFloat(_ vx:UnsafeMutableRawPointer, _ vy:UnsafeMutableRawPointer, _ min:Float, _ max:Float,  _ delta:Float, _ iname:String) {
        newEntry()
        data[dIndex].kind = .dualFloat
        data[dIndex].valuePointerX = vx
        data[dIndex].valuePointerY = vy
        addCommon(dIndex,min,max,delta,iname)
    }
    
    func addDropDown(_ vx:UnsafeMutableRawPointer, _ items:[String]) {
        newEntry()
        data[dIndex].kind = .dropDown
        data[dIndex].valuePointerX = vx
        for i in items { data[dIndex].str.append(i) }
    }
    
    func addLegend(_ iname:String) {
        newEntry()
        data[dIndex].kind = .legend
        data[dIndex].str.append(iname)
    }
    
    func addLine() {
        newEntry()
        data[dIndex].kind = .line
    }
    
    func  addMove() {
        newEntry()
        data[dIndex].kind = .move
        data[dIndex].str.append("Move")
    }

    func addCommand(_ iname:String, _ ncmd:CmdIdent) {
        newEntry()
        data[dIndex].kind = .command
        data[dIndex].str.append(iname)
        data[dIndex].cmd = ncmd
    }
    
    func addString(_ iname:String, _ cNumber:Int) {
        newEntry()
        data[dIndex].kind = .string
        data[dIndex].str.append(iname)
        data[dIndex].index = cNumber
    }
    
    func addColor(_ index:Int, _ height:Float) {
        newEntry()
        data[dIndex].kind = .color
        data[dIndex].index = index
        data[dIndex].deltaValue = height
    }
    
    //MARK:-
    
    func drawGraph(_ index:Int) {
        let d = data[index]
        let x:CGFloat = 5
        let rect = CGRect(x:x, y:py, width:GrphSZ, height:GrphSZ)
        
        if d.fastEdit { UIColor.black.set() } else { UIColor.red.set() }
        UIBezierPath(rect:rect).fill()
        
        if d.kind != .move {       // x,y cursor lines
            context!.setLineWidth(2)
            UIColor.white.set()
            
            let cx = rect.origin.x + d.valueRatio(0) * rect.width
            drawVLine(context!,cx,rect.origin.y,rect.origin.y + GrphSZ)
            
            if d.kind == .dualFloat {
                let y = rect.origin.y + (1.0 - d.valueRatio(1)) * rect.height
                drawHLine(context!,rect.origin.x,rect.origin.x + GrphSZ,y)
            }
        }
        
        UIColor.white.set()
        UIBezierPath(rect:rect).stroke()
    }
    
    func drawEntry(_ index:Int) {
        let tColor:UIColor = index == focus ? .green : .white
        data[index].yCoord = py
        
        switch(data[index].kind) {
        case .singleFloat, .dualFloat, .move :
            drawText(Tab2+10,py+TxtYoff,tColor,FontSZ,data[index].str[0])
            drawGraph(index)
            
        case .dropDown :
            drawText(Tab1,py+TxtYoff,tColor,FontSZ,data[index].str[data[index].getInt32Value()])
            
        case .command :
            drawText(Tab1,py+TxtYoff,tColor,FontSZ,data[index].str[0])
            
        case .string :
            drawText(Tab1,py+TxtYoff,tColor,FontSZ,wgGetString(data[index].index))
            
        case .legend :
            drawText(Tab2,py+TxtYoff,.yellow,FontSZ,data[index].str[0])
            
        case .line :
            UIColor.white.set()
            context?.setLineWidth(1)
            drawHLine(context!,0,bounds.width,py)
            py -= RowHT - 5
            
        case .color :
            let c = wgGetColor(data[index].index)
            c.setFill()
            let r = CGRect(x:1, y:py-4, width:bounds.width-2, height:CGFloat(data[index].deltaValue))
            UIBezierPath(rect:r).fill()
            py -= RowHT
        }
        
        py += RowHT
    }
    
    override func draw(_ rect: CGRect) {
        context = UIGraphicsGetCurrentContext()

        py = 10
        for i in 0 ..< data.count { drawEntry(i) }

        UIColor.white.setStroke()
        UIBezierPath(rect:bounds).stroke()
    }
    
    //MARK:-
    
    func update() -> Bool {
        if focus == NONE { return false }

        if data[focus].kind == .move {
            wgAlterPosition(deltaX,-deltaY)
            return true
        }

        if data[focus].isValueWidget() {
            if deltaX == 0 && deltaY == 0 { return false }
            
            let valueX = fClamp2(data[focus].getFloatValue(0) + deltaX * data[focus].deltaValue, data[focus].mRange)
            data[focus].valuePointerX.storeBytes(of:valueX, as:Float.self)
        
            if data[focus].kind == .dualFloat {
                let valueY = fClamp2(data[focus].getFloatValue(1) + deltaY * data[focus].deltaValue, data[focus].mRange)
                data[focus].valuePointerY.storeBytes(of:valueY, as:Float.self)
            }
        }
        
        setNeedsDisplay()
        return true
    }
    
    //MARK:-
    
    func stopChanges() { deltaX = 0; deltaY = 0 }
    
    func focusMovement(_ pt:CGPoint) {
        if focus == NONE { return }
        if pt.x == 0 {
            stopChanges()
            return
        }
        
        if frame.contains(pt) { return }
        
        var denom:Float = 1000
        
        if data[focus].kind == .move { denom = 30 }
        
        deltaX =  Float(pt.x) / denom
        deltaY = -Float(pt.y) / denom
        
        if !data[focus].fastEdit {
            let den = Float((data[focus].kind == .move) ? 10 : 100)
            deltaX /= den
            deltaY /= den
        }
        
        setNeedsDisplay()
    }
    
    //MARK:-
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        var pt = CGPoint()
        for touch in touches { pt = touch.location(in: self) }
        stopChanges()
        
        for i in 0 ..< data.count { // move Focus to this entry?
            
            if [ .singleFloat, .dualFloat, .command, .dropDown, .move ].contains(data[i].kind) {
                if pt.y >= data[i].yCoord && pt.y < data[i].yCoord + RowHT {
                    focus = i
                    setNeedsDisplay()
                    return
                }
            }
        }
    }
    
    override func touchesMoved(     _ touches: Set<UITouch>, with event: UIEvent?) { touchesBegan(touches, with:event) }
    override func touchesCancelled( _ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with:event) }
    
    override func touchesEnded( _ touches: Set<UITouch>, with event: UIEvent?) {
        if focus == NONE { return }
        
        if data[focus].kind == .dropDown {
            wgTableStrings = data[focus].str
            wgTableIndex = data[focus].getInt32Value()
            wgCommand(.funcList)
            return
        }
        
        if data[focus].kind == .command {
            wgCommand(data[focus].cmd)
            focus = NONE
            setNeedsDisplay()
        }
        
        stopChanges()
    }
    
    func functionNameChanged() {
        data[focus].valuePointerX.storeBytes(of:Int32(wgTableIndex), as:Int32.self)
        focus = NONE
        wgRefresh()
        setNeedsDisplay()
    }
    
    func fClamp2(_ v:Float, _ range:float2) -> Float {
        if v < range.x { return range.x }
        if v > range.y { return range.y }
        return v
    }
}
