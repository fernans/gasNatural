#include "utils.h"

void RGBtoHSV(int &RH, int &GS, int &BV) {
    float R,G,B;
    float H=0,S,V;
    R=RH/255.0f; G=GS/255.0f; B=BV/255.0f;
    float Mx=MAX(MAX(R,G),B);
    float Mn=MIN(MIN(R,G),B);
    V=Mx;
    if (Mx==0) S=0; else S=1.0-(Mn/Mx);
    if (Mx==Mn) H=240; // sin Tono concreto... cualquiera //0 rojo, 120 verde, 240 azul
    else {  // calcular y comprobar el tono concreto
        if (Mx==B) H=(((R-G)*60)/(Mx-Mn))+240;
        if (Mx==G) H=(((B-R)*60)/(Mx-Mn))+120;
        if (Mx==R) H=(((G-B)*60)/(Mx-Mn));
        if (H<0) H+=360;
                // H=0...360 -> escalar a 0...256
        // de 0..360 -> 0..1
        H=H/360.0f; //*0.7083; //*(255/360)
    } // sinTono

    // HSV de 0 a 1
    RH=(int)(H*255);
    GS=(int)(S*255);
    BV=(int)(V*255);
}

void RGBtoYUV(int &RY, int &GU, int &BV) {
    float R,G,B;
    float Y,U,V;
    // r,b and b are assumed to be in the range 0...1
    R=RY/255.0f; G=GU/255.0f; B=BV/255.0f;

    Y =   R * 0.299 + G * 0.587 + B * 0.114;
    U = - R * 0.1471376975169300226 - G * 0.2888623024830699774 + B * 0.436;
    V =   R * 0.615 - G * 0.514985734664764622 - B * 0.100014265335235378;

    // hue = atan( v, u );  // In this case hue will be between -Pi and Pi
    // saturation = Math.sqrt( u*u + v*v );  // saturation will be between 0 and 1/sqrt(2),
                                             // so you might want to multiply the saturation by sqrt(2)
                                             // to get it in a range between 0 and 1.

    // devolver valores entre 0 y 255
    RY=(int)(Y*255);
    GU=(int)(U*255);
    BV=(int)(V*255);
}

void blurImg(unsigned char *img, int w, int h) {
    unsigned char *cur=img+(w+1); //me salto la primera fila y primera columna
    unsigned char *prev=cur-1; //izq
    unsigned char *next=cur+1; //der
    float final;
    for (int y=1;y<(h-1);y++) { //desde la segunda fila, hasta la penultima
        for (int x=1;x<(w-1);x++) { //desde la segunda columna, hasta la penultima
            final=((*cur)+(*prev)+(*next))/3.0f;
            *cur=(unsigned char)final;
            prev++;
            cur++;
            next++;
        }
        cur+=2; //salto la ultima y primera columna
        next+=2;
        prev+=2;
    }
}

void blurImgY(unsigned char *img, int w, int h) {
    unsigned char *cur=img+(w+1); //me salto la primera fila y primera columna
    unsigned char *prev=cur-w; //arriba
    unsigned char *next=cur+w; //abajo
    float final;
    for (int y=1;y<(h-1);y++) { //desde la segunda fila, hasta la penultima
        for (int x=1;x<(w-1);x++) { //desde la segunda columna, hasta la penultima
            final=((*cur)+(*prev)+(*next))/3.0f;
            *cur=(unsigned char)final;
            prev++;
            cur++;
            next++;
        }
        cur+=2; //salto la ultima y primera columna
        next+=2;
        prev+=2;
    }
}

void integralImg(unsigned char *img, int w, int h, long *integral) {

}

