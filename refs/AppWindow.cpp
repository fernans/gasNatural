#include "AppWindow.h"

#include "video.h"
#include "ShivaUtil.h"
#include "utils.h"

#include <strings.h>

#include <windows.h>
#include <shellapi.h>

AppWindow::AppWindow(const char* label=0) : Fl_Window(0,0,300,180,label),
    button(20,30,260,100,"FullScreen"), buttonQuit(100,140,100,30,"Salir")
{
  button.box (FL_UP_BOX);
  button.labelsize (36);
  button.labelfont (FL_BOLD+FL_ITALIC);
  button.labeltype (FL_SHADOW_LABEL);

  buttonQuit.box (FL_UP_BOX);
  buttonQuit.labelsize (18);
  buttonQuit.labelfont (FL_ITALIC);

    imgAlfa=NULL;

    //initConfig(conf);
    conf.loadConfig("config.xml");


    // INIT VIDEO
    if( ferVideoOpen( const_cast<char*>(conf.videoConfigURL.c_str()) ) < 0 ) {
    //if( "camera_config.xml" < 0 ) {
        std::cout << "Error abriendo configuracion de video ("<< conf.videoConfigURL <<")" << std::endl;
        exit(-1);
    }
    if( ferVideoInqSize(&conf.camW, &conf.camH) < 0 ) {
        std::cout << "Error obteniendo tamaño de video" << std::endl;
        exit(-1);
    }
    printf("Image size (x,y) = (%d,%d)\n", conf.camW, conf.camH);
    unsigned long tam=conf.camH*conf.camW;
    imgAlfa = new unsigned char [tam];  //reservo imagen para alfa (se-reutiliza)
    ferVideoCapStart();

    //init shiva
    ShivaInit();
        // init Shiva
        ShivaLoadPack(conf.stkStartup, conf.stkPack);
        ShivaSetFullscreen();
        //ShivaSetWindowed(0,0,0,0);  //ocultar? shiva
        //ShivaGetUserEvent("aiCalibrate","onExternSetCalibrate", externSetCalibrate, this);
        ShivaGetUserEvent("main","onExternQuit", externQuit, this);
        ShivaGetUserEvent("main","onExternSetMin", externSetMin, this);
        ShivaGetUserEvent("main","onExternSetMax", externSetMax, this);
        ShivaGetUserEvent("main","onExternSetMode", externSetMode, this);
        ShivaGetUserEvent("main","onExternCloseCalibrate",externCloseCalibrate, this);
        //ShivaGetUserEvent("aiCalibrate","onExternTime",externCalibrateTime, this);
        //ShivaGetUserEvent("aiCalibrate","onExternMedia",externCalibrateMedia, this);
        //ShivaGetUserEvent("aiCalibrate","onExternPoint",externCalibratePoint, this);
        //ShivaGetUserEvent("aiCalibrate","onExternImageInput",externImageInput, this);
        ShivaGetUserEvent("main","onExternInit",externInit,this);

    Fl::add_timeout(1.0, timerCallback, (void*)this);
    button.callback(buttonFullScreen, (void*)this);
    buttonQuit.callback(buttonQuitCallback, (void*)this);

    //callback(focused, (void*)this);

    bRunning=true;
}

AppWindow::~AppWindow() {
    if (imgAlfa!=NULL) {free(imgAlfa); imgAlfa=NULL;}

    //end video
    ferVideoCapStop();
    ferVideoClose();

    ShivaEnd();
}

int AppWindow::handle(int event) {
    //std::cout << "Event: " << event << std::endl;
    if (event==FL_FOCUS) {
        //buttonFullScreen(NULL, this);
    }
    //AppWindow* _THIS=((AppWindow*)v);
    //_THIS->buttonFullScreen(fw,v);
    return Fl_Window::handle(event);
}

void AppWindow::externInit ( unsigned char _iArgumentCount, const void *_pArguments, void *_pUserData )
{
    //((AppWindow*)_pUserData);
    AppWindow* _THIS=((AppWindow*)_pUserData);
    std::cout << "externInit" << std::endl;
    ShivaSendUserEvent("main", "onSetCamera", _THIS->conf.camW, _THIS->conf.camH );
    ShivaSendUserEvent("main", "onSetMode", (float)_THIS->conf.mode );
    ShivaSendUserEvent("main", "onSetSliders", _THIS->conf.HSVs[0], _THIS->conf.HSVs[1], _THIS->conf.HSVs[2] );
    ShivaSendUserEvent("main", "onSetPrefijo", _THIS->conf.prefijo);
    ShivaSendUserEvent("main", "onSetTime", (float)_THIS->conf.wait);
    // cargar fondos
    for (std::list<std::string>::iterator it = _THIS->conf.fondos.begin(); it != _THIS->conf.fondos.end(); it++)
        ShivaSendUserEvent("main", "onAddFondo", *it);

    // ocultar ventana maestra
    //_THIS->iconize();
}

void AppWindow::timerCallback(void* v) {
    AppWindow* _THIS=((AppWindow*)v);

    if (_THIS->bRunning) {
        //capturar camara
        unsigned char *img;
        ferVideoCapNext();
        img=(unsigned char*) ferVideoGetImage();

        if (img!=NULL) {

            //procesar imagen
            unsigned char *pImg = img;
            unsigned char *pAlfa = _THIS->imgAlfa;
            int r,g,b,a,ah,as,av,d1,d2;
            float atemp;
            for (int y=0;y<_THIS->conf.camH;y++) {
                for (int x=0;x<_THIS->conf.camW;x++) {
                    //*pImg=1;
                    b=(int)*pImg; pImg++;
                    //*pImg=253;
                    g=(int)*pImg; pImg++;
                    //*pImg=0;
                    r=(int)*pImg; pImg++;
                    pImg++;

                    if (_THIS->conf.mode==1) RGBtoHSV(r,g,b);
                    else if (_THIS->conf.mode==2) RGBtoYUV(r,g,b);

                    if (_THIS->conf.dist==0) { // margenes 3 niveles
                        ah=as=av=0;
                        atemp=255;
                        if (g>(int)_THIS->conf.HSV[1]-(int)_THIS->conf.HSVs[1])
                        if (g<(int)_THIS->conf.HSV[1]+(int)_THIS->conf.HSVs[1])
                        if (r>(int)_THIS->conf.HSV[0]-(int)_THIS->conf.HSVs[0])
                        if (r<(int)_THIS->conf.HSV[0]+(int)_THIS->conf.HSVs[0])
                        if (b>(int)_THIS->conf.HSV[2]-(int)_THIS->conf.HSVs[2])
                        if (b<(int)_THIS->conf.HSV[2]+(int)_THIS->conf.HSVs[2])
                        atemp=0;
                    } else if (_THIS->conf.dist==1) { // distancia 1 nivel (euclidean)
                        ah=(r-_THIS->conf.HSV[0]); ah*=ah;
                        as=(g-_THIS->conf.HSV[1]); as*=as;
                        av=(b-_THIS->conf.HSV[2]); av*=av;
                        d1=_THIS->conf.HSVs[0]; d1*=d1;
                        if ((ah+as+av)<d1) atemp=0; else atemp=255;
                    } else if (_THIS->conf.dist==2) { // distancia 1 nivel con margen
                        ah=(r-_THIS->conf.HSV[0]); ah*=ah;
                        as=(g-_THIS->conf.HSV[1]); as*=as;
                        av=(b-_THIS->conf.HSV[2]); av*=av;
                        d1=_THIS->conf.HSVs[0]; d1*=d1;
                        if ((ah+as+av)<d1) atemp=0; else {
                            d2=_THIS->conf.HSVs[0]+_THIS->conf.HSVs[1]; d2*=d2;
                            if ((ah+as+av)>d2 || d2<=d1) atemp=255; else {
                                atemp=((float)((ah+as+av)-d1)/(float)(d2-d1))*255;
                            }
                        }
                    }

                    if (atemp>255) atemp=255;
                    a=(unsigned char)atemp;

                    *pAlfa=a; pAlfa++;
                }
            }
            //blur de alfa
            blurImg( _THIS->imgAlfa, _THIS->conf.camW, _THIS->conf.camH);
            blurImgY( _THIS->imgAlfa, _THIS->conf.camW, _THIS->conf.camH);
            blurImg( _THIS->imgAlfa, _THIS->conf.camW, _THIS->conf.camH);
            blurImgY( _THIS->imgAlfa, _THIS->conf.camW, _THIS->conf.camH);
            //memset(imgAlfa, 0, tam);
            //memset(imgAlfa+(tam/2), 255, tam/2);

            //Enviar Imagen a Shiva
            ShivaSendImageAlfa(img,  _THIS->imgAlfa, _THIS->conf.camW, _THIS->conf.camH, true );
        }

        ShivaPaint();
        Fl::repeat_timeout(1/60, timerCallback, v);

    } else { //not Running (QUIT)
        //hacer nada, hasta que vuelva el foco (fullscreen)
        //_THIS->hide();
    }
}

// These parameter values are guesses - you'll need to tweak them
/*
float target_hue = 1.0f / 3;
float tolerance_hue = 0.1f;
float min_saturation = 0.5f;
float min_lightness = 0.3f;
float max_lightness = 0.8f;
float ComputeOpacity(float hue, float stauration, float lightness) {
        if (saturation < min_saturation) return 1.0f;
        if (lightness < min_lightness) return 1.0f;
        if (lightness > max_lightness) return 1.0f;
        float delta_hue = fabsf(hue - target_hue);
        float opacity = 1.0f - (delta_hue / tolerance_hue);
        if (opacity < 0.0f) opacity = 0.0f;
        return opacity;
    }
//*/

void AppWindow::buttonFullScreen(Fl_Widget *fw, void* v) {
    AppWindow* _THIS=((AppWindow*)v);
    _THIS->bRunning=true;
    //Fl::repeat_timeout(1/60, timerCallback, v);
    ShivaSetFullscreen();
    //_THIS->iconize();
}

void AppWindow::buttonQuitCallback(Fl_Widget *fw, void *v) {
    AppWindow* _THIS=((AppWindow*)v);
    _THIS->bRunning=false;
    _THIS->hide();
}

void AppWindow::externQuit ( unsigned char _iArgumentCount, const void *_pArguments, void *_pUserData )
{
    //((AppWindow*)_pUserData);
    AppWindow* _THIS=((AppWindow*)_pUserData);
    //_THIS->bRunning=false;
    ShivaSetWindowed(0,0,0,0); //minimizar a la esquina

    // si está configurado (conf.appUrl)
    // lanzar y esperar aplicacion externa
    //if ((_THIS->conf).appUrl!=NULL) {
    if (_THIS->conf.appUrl.length()>0) {

        std::cout << "Iniciando aplicacion: " << _THIS->conf.appUrl << std::endl;

       // _THIS->bRunning=true; // no detener shiva

        SHELLEXECUTEINFO ShellInfo; // Name structure
        memset(&ShellInfo, 0, sizeof(ShellInfo)); // Set up memory block
        ShellInfo.cbSize = sizeof(ShellInfo); // Set up structure size
        ShellInfo.hwnd = NULL; // Calling window handle
        ShellInfo.lpVerb = NULL; // "open"/"launch"Open the file with default program
        ShellInfo.lpFile = _THIS->conf.appUrl.c_str(); // File to open
        ShellInfo.nShow = SW_NORMAL; // Open in normal window
        ShellInfo.fMask = SEE_MASK_NOCLOSEPROCESS; // Necessary if you want to wait for spawned process
        bool res = ShellExecuteEx(&ShellInfo); // Call to function
        if (res)
            WaitForSingleObject(ShellInfo.hProcess, INFINITE); // wait forever for process to finish

        // volver a lanzar shiva
        _THIS->bRunning=true;
        //Fl::repeat_timeout(1/60, timerCallback, _pUserData);
        ShivaSetFullscreen();
        //_THIS->iconize();

        //lamar a la aplicacion externa
        //ShellExecute(NULL,NULL,"calc.exe",NULL,NULL,SW_SHOW);
    }
}

void AppWindow::externCloseCalibrate( unsigned char _iArgumentCount, const void *_pArguments, void *_pUserData ) {
    AppWindow* _THIS=((AppWindow*)_pUserData);
    _THIS->conf.saveConfig("config.xml");
}

void AppWindow::externSetMin ( unsigned char _iArgumentCount, const void *_pArguments, void *_pUserData )
{
    //((AppWindow*)_pUserData);
    AppWindow* _THIS=((AppWindow*)_pUserData);
    const S3DX::AIVariable *pVariables = (const S3DX::AIVariable *)_pArguments ;
    if ( _pArguments && ( _iArgumentCount == 3 ) ) {
        int r,g,b;
        r=pVariables[0].GetNumberValue();
        g=pVariables[1].GetNumberValue();
        b=pVariables[2].GetNumberValue();
        if (_THIS->conf.mode==1) RGBtoHSV(r,g,b);
        else if (_THIS->conf.mode==2) RGBtoYUV(r,g,b);
        _THIS->conf.HSV[0]=r;
        _THIS->conf.HSV[1]=g;
        _THIS->conf.HSV[2]=b;

        std::cout << "SetHSV" << std::endl;
        std::cout << "HSV = " <<  _THIS->conf.HSV[0] << "," <<  _THIS->conf.HSV[1] << "," <<  _THIS->conf.HSV[2] << std::endl;
    }
}

void AppWindow::externSetMax ( unsigned char _iArgumentCount, const void *_pArguments, void *_pUserData )
{
    //((AppWindow*)_pUserData);
    AppWindow* _THIS=((AppWindow*)_pUserData);
    const S3DX::AIVariable *pVariables = (const S3DX::AIVariable *)_pArguments ;
    if ( _pArguments && ( _iArgumentCount == 3 ) ) {
        unsigned char r,g,b;
        // r,g,b es directamente el margen permitido para HSV
        r=pVariables[0].GetNumberValue();
        g=pVariables[1].GetNumberValue();
        b=pVariables[2].GetNumberValue();
        //RGBtoHSV(r,g,b);
        //r=abs(_THIS->conf.HSV[0]-r);
        //g=abs(_THIS->conf.HSV[1]-g);
        //b=abs(_THIS->conf.HSV[2]-b);
        _THIS->conf.HSVs[0]=r;
        _THIS->conf.HSVs[1]=g;
        _THIS->conf.HSVs[2]=b;

        std::cout << "SetHSV smoothing" << std::endl;
        std::cout << "HSV = " <<  _THIS->conf.HSVs[0] << "," <<  _THIS->conf.HSVs[1] << "," <<  _THIS->conf.HSVs[2] << std::endl;
    }
}

void AppWindow::externSetMode ( unsigned char _iArgumentCount, const void *_pArguments, void *_pUserData )
{
    //((AppWindow*)_pUserData);
    AppWindow* _THIS=((AppWindow*)_pUserData);
    const S3DX::AIVariable *pVariables = (const S3DX::AIVariable *)_pArguments ;
    if ( _pArguments && ( _iArgumentCount == 1 ) ) {
        int m;
        m=pVariables[0].GetNumberValue();
        _THIS->conf.mode=m;
        std::cout << "SetRGBmode: " << m << std::endl;
    }
}
