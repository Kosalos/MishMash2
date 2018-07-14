#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "MishMash.h"

Control *cPtr = NULL;

void setControlPointer(Control *ptr) { cPtr = ptr; }

void setGrammarCharacter(int index, char chr) { cPtr->grammar[index] = chr; }
int  getGrammarCharacter(int index) {      // 49,50,51,52,0  
    int ch = (int)(cPtr->grammar[index]);
    return ch;
}

int rndI(int max) { return rand() % max; }
float rndF(float min,float max) { return min + (max-min) * (float)(rand() % 1000) / 1000; }

void controlRandomGrammar(void) {
    cPtr->grammar[0] = '1';
    for(int i=1;i<MAX_GRAMMER;++i) {
        cPtr->grammar[i] = (char)('1' + rndI(5));
        if(cPtr->grammar[i] == '5') cPtr->grammar[i] = 0;
    }
    cPtr->grammar[MAX_GRAMMER] = 0;
}

void controlRandom(void) {
    srand((unsigned int)clock());
    
    cPtr->xmin = -4;    // initial position & zoom
    cPtr->xmax = +4;
    cPtr->ymin = -4;
    cPtr->ymax = +4;

    for(int i=0;i<NUM_FUNCTION;++i) {
        Function *f = &(cPtr->function[i]);
        f->index = rndI(20);
        f->xT = rndF(-0.3,0.3);
        f->yT = rndF(-0.3,0.3);
        f->rot = rndF(-2,2);
        f->xS = rndF(0.9,1.1);
        f->yS = rndF(0.9,1.1);
    }

    controlRandomGrammar();

    cPtr->stripeDensity = rndF(-9,9);
    cPtr->escapeRadius = rndF(1,50);
    cPtr->multiplier = rndF(-1,1);
    cPtr->R = rndF(0.1,1);
    cPtr->G = rndF(0.1,1);
    cPtr->B = rndF(0.1,1);
    cPtr->contrast = rndF(0.1,5);
    
    cPtr->smooth = 0;
    cPtr->zoom = 0;
}

char *controlDebugString(void) {
    static char str[1024];
    sprintf(str,"V: %d\nFunc: %d,%d,%d,%d\nM: %8.5f\n",
            cPtr->version,
            cPtr->function[0].index,
            cPtr->function[1].index,
            cPtr->function[2].index,
            cPtr->function[3].index,
            cPtr->multiplier);
    return str;
}

int* funcIndexPointer(int fIndex) { return &(cPtr->function[fIndex].index); }
int  funcIndex(int fIndex) { return cPtr->function[fIndex].index; }

float* funcXtPointer(int fIndex) { return &(cPtr->function[fIndex].xT); }
float* funcYtPointer(int fIndex) { return &(cPtr->function[fIndex].yT); }
float* funcXsPointer(int fIndex) { return &(cPtr->function[fIndex].xS); }
float* funcYsPointer(int fIndex) { return &(cPtr->function[fIndex].yS); }
float* funcRotPointer(int fIndex) { return &(cPtr->function[fIndex].rot); }

int isFunctionActive(int index) {
    for(int i=0;i<MAX_GRAMMER;++i) {
        if(cPtr->grammar[i] == 0) return 0;
        if(cPtr->grammar[i] - 49 == index) return 1;
    }
    
    return 0;
}

//MARK: -

#define NUM_AUTO 26
static float AMangle[NUM_AUTO];
static float AMdeltaAngle[NUM_AUTO] = { 0 };
static float AMradius[NUM_AUTO];

void controlInitAutoMove(void) {
    for(int i=0;i<NUM_AUTO;++i) {
        AMdeltaAngle[i] = rndF(0.001,0.01);
        AMradius[i] = 0.0001 + rndF(0.0001,0.0005);
    }
}

#define pi2 ((float)(3.141592654 * 2.0))
    
void controlAutoMove(void) {
    int index = 0;
    for(int i=0;i<NUM_AUTO;++i) {
        AMangle[i] += AMdeltaAngle[i];
        if(AMangle[i] >= pi2) AMangle[i] -= pi2;
        
        float amt = sinf(AMangle[i]) * AMradius[i];
        
        switch(i) {
            case 0 : cPtr->multiplier += amt;   break;
            case 1 : cPtr->stripeDensity += amt;   break;
            case 2 : cPtr->escapeRadius += amt;   break;
            case 3 : cPtr->R += amt;   break;
            case 4 : cPtr->G += amt;   break;
            case 5 : cPtr->B += amt;   break;
            case 6 :
            case 11:
            case 16:
            case 21:
                index = (i-6)/5;
                cPtr->function[index].xT += amt; break;
            case 7 :
            case 12:
            case 17:
            case 22:
                index = (i-7)/5;
                cPtr->function[index].yT += amt; break;
            case 8 :
            case 13:
            case 18:
            case 23:
                index = (i-8)/5;
                cPtr->function[index].xS += amt; break;
            case 9 :
            case 14:
            case 19:
            case 24:
                index = (i-9)/5;
                cPtr->function[index].yS += amt; break;
            case 10:
            case 15:
            case 20:
            case 25:
                index = (i-10)/5;
                cPtr->function[index].rot += amt; break;
        }
    }
}


    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    














