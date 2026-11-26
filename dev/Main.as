package  {
	
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.ui.Keyboard;
	import flash.ui.Mouse;
	import flash.display.Bitmap;
	import flash.desktop.NativeApplication;
	import flash.system.Capabilities;
	import flash.display.StageDisplayState;
	import flash.display.StageScaleMode;
	import flash.display.StageAlign;
	import flash.geom.Point;
	import flash.geom.Vector3D;
	import flash.geom.Matrix3D;
	import flash.net.URLRequest;
	import flash.net.Socket;
	
	
	import com.as3nui.nativeExtensions.air.kinect.*;
	import com.as3nui.nativeExtensions.air.kinect.events.*;
	import com.as3nui.nativeExtensions.air.kinect.data.User;
	import com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone;
	import com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint;
	
	import away3d.containers.*;
	import away3d.entities.*;
	import away3d.materials.*;
	import away3d.textures.BitmapTexture;
	import away3d.primitives.*;
	import away3d.entities.Mesh;
	import away3d.primitives.CubeGeometry;
	import away3d.utils.*;
	import away3d.events.*;
	import away3d.library.assets.IAsset;
	import away3d.library.AssetLibrary;
	import away3d.loaders.*;
	import away3d.loaders.parsers.*;
	import away3d.animators.data.Skeleton;
	import away3d.animators.data.SkeletonJoint;
	import away3d.animators.data.SkeletonPose;
	import away3d.animators.data.JointPose;
	import away3d.animators.nodes.SkeletonClipNode;
	import away3d.animators.SkeletonAnimator;
	import away3d.animators.SkeletonAnimationSet;
	
	
	import flash.display.BitmapData;
	import flash.events.MouseEvent;
	
	import flash.geom.Matrix;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.media.Video;
	import flash.events.NetStatusEvent;
	import flash.events.AsyncErrorEvent;
	import away3d.core.math.Quaternion;
	import flash.net.dns.AAAARecord;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import away3d.library.utils.AssetLibraryIterator;
	import away3d.core.base.Object3D;
	import away3d.cameras.lenses.PerspectiveLens;
	import flash.net.SharedObject;
	import away3d.tools.helpers.data.MeshDebug;
	import flash.utils.ByteArray;
	import flash.net.FileReference;
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.filesystem.FileMode;
	import com.adobe.images.JPGEncoder;
	import flash.display.BitmapDataChannel;
	import flash.geom.ColorTransform;
	import flash.filters.BlurFilter;
	import flash.filters.BitmapFilterQuality;
	import flash.geom.Rectangle;
	import flash.display.Sprite;
	
	
	public class Main extends MovieClip {
		
		// ------------------
		// min-fer = 4    (160x120)
		// normal  = 1    (640x480)
		// super   = 0.5 (1280x960)
		public const fer_escalar:Number=0.5;	// 0.5/4	// 1=640x480=ok 0.8=800x600=no 0.625=1024x768=no 0.5=1280x960=ok
		public const fer_croma:Boolean=false;		// solo por color	
		public const fer_cromaMedio:Boolean=true;	// analizar a media resolucion (solo por color)
		public const fer_cromaKinect:Boolean=true;	// solo por kinect
		public const fer_cromaHuevo:Boolean=true;	// poner huevo en cabeza (para asegurar croma en pelo)
		public const fer_cromafino:Boolean=false;	// suavizar bordes de alfa (de color o kinect)
		public const fer_cromaMostrarFondo:Boolean=true; 	// mostrar siempre el fondo (sin nadie)
		public const fer_grafica:Boolean=true;	
		public const fer_video:Boolean=false;		// fondo fijo
		public const fer_3d:Boolean=true;		
		public const fer_3dbrazos:Boolean=false;	// experimental (alargar codos)
		public const fer_autoScale:Boolean=true;	// auto escala la geometria, en base al skel-kinect
		public const fer_over:Boolean=true;	
		// ------------------
		
		// estados
		public const ESTADO_PREINIT=1; 	// antes de iniciar
		public const ESTADO_INIT=2;		// iniciando kinect
		public const ESTADO_ESCENA=3;	// en escena (tanto si hay jugador o no)
		public const ESTADO_FOTO=4; 	// cuenta atrás y sacar foto
		public const ESTADO_DATOS=5;	// introducir mail (teclado normal)
		public const ESTADO_DATOS2=6;	// aceptar pop-up
		public const ESTADO_FIN=7;	  	// gracias, y vuelta a escena
		private var estado:Number=ESTADO_PREINIT;
		
		private var modelo:Number=0;
		private const maxModelos:Number=3;
		
		private var calibrando:Boolean=false;
		private var so:SharedObject=null;
		
		// kinect
		private var device:Kinect=null;
		private var camara:Bitmap;		// <-- solo para mostrar en 2D
		private var bmdOrig:BitmapData;	// pre-croma
		private var bmdMask:BitmapData;	// userMask-croma (recibida a mitad de resolucion)
		private var bmdMask2:BitmapData; // escalada a full res.
		private var bmd:BitmapData;		// con croma
		private var bmd2:BitmapData;	// escalado a potencia de 2 (1024x1024)
		private var bmd2m:Matrix;		// (transformacion a potencia de 2)
		private var bmd2t:BitmapTexture; // textura para away3D
		private var currentUser:User=null;
		
		private var maskMat:Matrix;
		private var mascaraScale:Number=2;
		private var mascaraOffsetX:Number=0;
		private var mascaraOffsetY:Number=0;
		private var hideGeom:Boolean=false;
		
		// away3D
		private var _view:View3D;
		private var elementsLoaded:int=0;
		private var elementsToLoad:int=0;
		
		private var cajasContainer:Mesh=new Mesh(null);
		private var cajas:Vector.<Mesh>=new Vector.<Mesh>();
		
		private var jointMapping:Dictionary=new Dictionary();
		private var rootPose:Vector.<SkeletonPose>=new Vector.<SkeletonPose>();		// posiciones actuales (joinPoses) del modelo-away
		private var kinectPose:Dictionary; //Vector.<Matrix3D>; 	// posiciones destino (calculada de kinect)
		
		private var _localPoses:Vector.<JointPose>; // poses iniciales (no lo necesito)
    	private var _bindPoses:Vector.<Matrix3D>;   // matrix de poses iniciales (no lo necesito)
		
		private var geomRutas:Array=["media/pijama.awd", "media/albornoz.awd", "media/delantal.awd"];
		private var geomJointsPerVertex:Array=[4,4,4]; // 5-pijama, 4-albornoz, 4-delantal
		private var hero:Mesh; 	// geometria actual
		private var geom:Vector.<Mesh>=new Vector.<Mesh>();
		private var skeleton:Skeleton; // eskeleton actual
		private var skeletons:Vector.<Skeleton>=new Vector.<Skeleton>;
	
		private var geomScaleX:Number=20;
		private var geomScaleY:Number=20;
		private var geomScaleZ:Number=20;
		
		private var geomBaseHeight:Number=1;
		private var geomBaseWidth:Number=1;
		private var offsetScaleX:Number=1;
		private var offsetScaleY:Number=1;
		private var offsetScaleZ:Number=1;
		
		// chroma
		private var a:Vector.<uint>=new Vector.<uint>();
		
		// videos fondos
		private var nc:NetConnection;
		private var ns:NetStream;
		private var video:Video;
		private var fondosFijos:Array=[FondoDormitorio,FondoDucha,FondoCocina];
		private var fondos:Array=["media/DORMITORIO.mov", "media/DUCHA.mov", "media/COCINA.mov"];
		
		private var sonidos:HolderSonidos=new HolderSonidos();
		
		// over
		private var mano:Mano;
		private var manoPulsando:MovieClip=null;
		private var manoTimer:Timer=new Timer(2*1000);   // 2 segundos sobre
		private var faldon:BitmapData=new Faldon(); // FaldonCatalan();  Faldon();
		
		// MCE
		// standard port: 5150
		private var mce:Socket=new Socket();
		private var mceDir:Boolean=true;
		
		// ------------------------------------------------------------------------------- MAIN
		
		public function Main() {
			// constructor code
			gotoEstado(ESTADO_PREINIT);
			addEventListener(Event.ADDED_TO_STAGE,init);
		}
		public function init(e:Event=null) {
			removeEventListener(Event.ADDED_TO_STAGE,init);
			gotoEstado(ESTADO_INIT);
		}
		
		// ------------------------------------------------------------------------------- ESTADOS
		public function gotoEstado(nuevoEstado:Number) {
			// salir de estado
			if (salirEstado(estado)) { // return false permite anular el cambio de estado
				// cambio de estado
				estado=nuevoEstado
				gotoAndStop(estado);
				// entrar en nuevo estado
				entrarEstado(estado);
			}
		}
		
		public function entrarEstado(e:Number) {
			switch (e) {
				case ESTADO_PREINIT:
					// nada (esperar a ADDED_TO_STAGE)
				break;
				case ESTADO_INIT:
					initEntrar();
				break;
				case ESTADO_ESCENA:
					escenaEntrar();
				break;
				case ESTADO_FOTO:
					fotoEntrar();
				break;
				case ESTADO_DATOS:
					datosEntrar();
				break;
				case ESTADO_DATOS2:
					datosEntrar2();
				break;
				case ESTADO_FIN:
					finEntrar();
				break;
				default: break;
			}
		}
		
		public function salirEstado(e:Number):Boolean {
			switch (e) {
				case ESTADO_PREINIT:
					// nada (esperar a ADDED_TO_STAGE)
				break;
				case ESTADO_INIT:
					// nada... (todo iniciado OK)
				break;
				case ESTADO_ESCENA:
					escenaSalir();
				break;
				case ESTADO_FOTO:
					fotoSalir();
				break;
				case ESTADO_DATOS:
					datosSalir();
				break;
				case ESTADO_DATOS2:
					datosSalir2();
				break;
				case ESTADO_FIN:
					// nada... (volver a escena libremente)
				break;
				default: break;
			}
			return true; // por defecto, se permite el cambio de estado
		}
		
		// ---------------------------------------------------------------------------------- EXIT
		public function end(e:Event=null) {
			stage.nativeWindow.removeEventListener(Event.CLOSING,end);
			//NativeApplication.nativeApplication.removeEventListener(Event.EXITING, end);
			if (device!=null) {
				trace("finalizando kinect");
				bmdOrig=null;
				device.stop();
				//device.removeEventListener(UserEvent.USERS_MASK_IMAGE_UPDATE, camUpdate);
				//device.removeEventListener(CameraImageEvent.RGB_IMAGE_UPDATE, camUpdate);
				//stage.removeEventListener(Event.ENTER_FRAME, camUpdate);
				device.removeEventListener(UserEvent.USERS_ADDED, playerEnters);
				device.removeEventListener(UserEvent.USERS_REMOVED, playerExits);
				device.dispose();
			}
			trace("saliendo");
			
			var t:Timer = new Timer(100);
			t.addEventListener(TimerEvent.TIMER, onTimerSalir);
			t.start();
		
		}
		private function onTimerSalir(e:TimerEvent) {
			NativeApplication.nativeApplication.exit();
		}
		
		// ---------------------------------------------------------------------------------- TECLA
		public function tecla(e:KeyboardEvent=null) {			
			if (e.keyCode==Keyboard.BACKSPACE && e.ctrlKey && e.altKey) gotoEstado(this.ESTADO_ESCENA); // reset			
			if (e.keyCode==Keyboard.ESCAPE && e.ctrlKey && e.altKey) end();
			if (e.keyCode==Keyboard.C && e.altKey && e.ctrlKey) {
				calibrarSwap();
			}
			if (this.calibrando) {
				var step:Number=10;
				if (e.ctrlKey) step*=10;
				if (e.shiftKey) step*=0.1;
				// camara
				if (e.keyCode==Keyboard.A) {_view.camera.x+=step;vistaGuardar();}
				if (e.keyCode==Keyboard.D) {_view.camera.x-=step;vistaGuardar();}
				if (e.keyCode==Keyboard.W) {_view.camera.y-=step;vistaGuardar();}
				if (e.keyCode==Keyboard.S) {_view.camera.y+=step;vistaGuardar();}
				if (e.keyCode==Keyboard.Q) {_view.camera.z-=step;vistaGuardar();}
				if (e.keyCode==Keyboard.E) {_view.camera.z+=step;vistaGuardar();}
				if (e.keyCode==Keyboard.O) {(_view.camera.lens as PerspectiveLens).fieldOfView-=step;vistaGuardar();}
				if (e.keyCode==Keyboard.P) {(_view.camera.lens as PerspectiveLens).fieldOfView+=step;vistaGuardar();}
				// mascara
				if (e.keyCode==Keyboard.RIGHT) {mascaraOffsetX+=step;mascaraGuardar();}
				if (e.keyCode==Keyboard.LEFT)  {mascaraOffsetX-=step;mascaraGuardar();}
				if (e.keyCode==Keyboard.UP)    {mascaraOffsetY-=step;mascaraGuardar();}
				if (e.keyCode==Keyboard.DOWN)  {mascaraOffsetY+=step;mascaraGuardar();}
				if (e.keyCode==Keyboard.COMMA) {mascaraScale-=step*0.01;mascaraGuardar();}
				if (e.keyCode==Keyboard.PERIOD)  {mascaraScale+=step*0.01;mascaraGuardar();}
				if (e.keyCode==Keyboard.BACKSPACE) hideGeom=!hideGeom;
				// blur
				if (e.keyCode==Keyboard.Z) {blur.blurX-=step;blur.blurY-=step;guardarBlur();}
				if (e.keyCode==Keyboard.X) {blur.blurX+=step;blur.blurY+=step;guardarBlur();}
				// escala geometria
				if (e.keyCode==Keyboard.G) {geomScaleX+=step*0.1;geomGuardar();}
				if (e.keyCode==Keyboard.J) {geomScaleX-=step*0.1;geomGuardar();}
				if (e.keyCode==Keyboard.Y) {geomScaleY-=step*0.1;geomGuardar();}
				if (e.keyCode==Keyboard.H) {geomScaleY+=step*0.1;geomGuardar();}
				if (e.keyCode==Keyboard.T) {geomScaleZ-=step*0.1;geomGuardar();}
				if (e.keyCode==Keyboard.U) {geomScaleZ+=step*0.1;geomGuardar();}
			}
			/*
			if (e.keyCode==Keyboard.ENTER) {
				botonFotoClick();
			}
			if (e.keyCode==Keyboard.SPACE) {
				botonFondoClick();
			}
			//*/
		}
		
		// ---------------------------------------------------------------------------------- INIT
		public function initEntrar() {
			// poner pantalla completa ---------------------------------------------
			debug.visible=false;
			alert_calibrando.visible=false;
			if (!Capabilities.isDebugger)
			{
				//stage.displayState=StageDisplayState.FULL_SCREEN_INTERACTIVE;
				stage.scaleMode=StageScaleMode.SHOW_ALL;
				Mouse.hide();
			}
			//stage.align=""; // center v, center h
			stage.align=StageAlign.TOP_LEFT;
			//NativeApplication.nativeApplication.addEventListener(Event.EXITING, end);
			stage.nativeWindow.addEventListener(Event.CLOSING,end);
			NativeApplication.nativeApplication.addEventListener(Event.DEACTIVATE, appOut);
			NativeApplication.nativeApplication.addEventListener(Event.ACTIVATE, appIn);
			
			stage.addEventListener(KeyboardEvent.KEY_DOWN, tecla);
			
			
			// iniciar kinect ------------------------------------------------------
			alert_ErrorKinect.visible=false;
			if (Kinect.isSupported()) {
				trace("Iniciando Kinect...");
				device=Kinect.getDevice();
				var settings:KinectSettings=new KinectSettings();
				settings.rgbEnabled=true;
				settings.rgbResolution=new Point(640/fer_escalar,480/fer_escalar);
				settings.userMaskEnabled=true;
				settings.userMaskResolution=new Point(640/(2*fer_escalar), 480/(2*fer_escalar)); // mitad que color
			
				device.addEventListener(CameraImageEvent.RGB_IMAGE_UPDATE, camRgbUpdate);
				device.addEventListener(UserEvent.USERS_MASK_IMAGE_UPDATE, camMaskUpdate);
				
				settings.skeletonEnabled=true;
				
				device.addEventListener(UserEvent.USERS_ADDED, playerEnters);
				device.addEventListener(UserEvent.USERS_REMOVED, playerExits);
				device.start(settings);
				trace("Kinect iniciada");
				
				if (!this.fer_grafica) {					
					// iniciar imagen de camara (visible normal)
					camara=new Bitmap();
					camara.scaleX=camara.scaleY=fer_escalar;
					camara_holder.addChild(camara);
				} else camara_holder.visible=false;
				stage.addEventListener(MouseEvent.MOUSE_DOWN, cogerColorIni);
				stage.addEventListener(MouseEvent.MOUSE_MOVE, cogerColorMove);
				stage.addEventListener(MouseEvent.MOUSE_UP, cogerColorFin);
				stage.addEventListener(MouseEvent.MOUSE_WHEEL, ajustarUmbral);
				
				// inicializacion completada
				gotoEstado(ESTADO_ESCENA);
			} else {
				trace("Kinect no conectada");
				alert_ErrorKinect.visible=true;
			}
			
			// iniciar away3D ----------------------------------------------------
			trace("Iniciando Away3D...");
			//setup the view
			_view = new View3D();
			addChild(_view);
			//setup the camera
			_view.antiAlias=2;
			//_view.camera.z = -100;
			//_view.camera.lookAt(new Vector3D(0,0,0));
			//_view.camera.y = 30;
			stage.addEventListener(Event.RESIZE, away_onResize);
			away_onResize();
			addEventListener(Event.ENTER_FRAME, away_onEnterFrame);

// SDK says: vertical 43
// For the color camera:
//    Horizontal FOV: 62,0°
//    Vertical FOV: 48,6°
// For the depth camera:
//    Horizontal FOV: 58,5°
//    Vertical FOV: 45,6°

			/*
			// debug
			_view.camera.x=150;
			_view.camera.y=-100;
			_view.camera.z=1200;
			//*/

			// real
			_view.camera.lens=new PerspectiveLens(30);
			_view.camera.rotationZ=-90;
			_view.camera.z=300;
			_view.camera.x=-80;
			_view.camera.y=100;

			if (this.fer_3d) {
				// cajas
				var rojoMat:ColorMaterial=new ColorMaterial(0xFF0000);
				var verdeMat:ColorMaterial=new ColorMaterial(0x00FF00);
				var azulMat:ColorMaterial=new ColorMaterial(0x00AAFF);
				var blancoMat:ColorMaterial=new ColorMaterial(0xFFFFFF);
				for (var i:int=0;i<50;i++) {
					// 20 huesos-cajas
					var ob:Mesh=new Mesh(new CubeGeometry(10,10,10), blancoMat);
					
					var palo:Mesh=new Mesh(new CubeGeometry(200,20,20), blancoMat);
					palo.x=-100;
					ob.addChild(palo);
					//*
					var r:Mesh=new Mesh(new CubeGeometry(100,5,5), rojoMat );
					r.x=50;
					ob.addChild(r);
					var g:Mesh=new Mesh(new CubeGeometry(5,100, 5), verdeMat );
					g.y=50;
					ob.addChild(g);
					var b:Mesh=new Mesh(new CubeGeometry(5, 5,100), azulMat );
					b.z=50;
					ob.addChild(b);
					ob.visible=false;
					
					cajas.push(ob);
					cajasContainer.addChild(ob);
				}
				cajasContainer.visible=false;
				_view.scene.addChild(cajasContainer);
				
				// load models			
				AssetLibrary.enableParser(AWD2Parser);
				AssetLibrary.enableParser(MD5MeshParser);
				AssetLibrary.addEventListener(AssetEvent.ASSET_COMPLETE, onAssetComplete);
				AssetLibrary.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);
				AssetLibrary.addEventListener(LoaderEvent.LOAD_ERROR, onLoadError);
				elementsToLoad=1;
				elementsLoaded=0;
				AssetLibrary.load(new URLRequest(this.geomRutas[geom.length]));
			}
			trace("Away3D iniciado");
			
			
			// --- iniciar Videos fondo ---------------------------------------------------
			if (this.fer_video) {
				trace("Iniciando Videos Fondo...");
				nc=new NetConnection();
				nc.connect(null);
				ns=new NetStream(nc);
				ns.addEventListener(NetStatusEvent.NET_STATUS, netStatus);
				ns.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
				ns.client=this;
				//ns.bufferTime=10;
				video=new Video(1024,1024);
				video.attachNetStream(ns);
				ns.play(this.fondos[this.modelo]);
				trace("Videos fondo Iniciado");
			} else {
				// fondos fijos CON AUDIO
				sonidos.gotoAndStop(1);
			}
			
			
			// cursor-mano -----------------------------------------------
			if (this.fer_over) {
				mano=new Mano();
				mano.visible=false;
				addChild(mano);
				manoTimer.addEventListener(TimerEvent.TIMER,manoTimerComplete);
			} else {
				botonFoto.visible=false;
				botonFondo.visible=false;
			}
			mce.connect("localhost",5150);
			
			// ------------------------------------------ shared object ---------------
			this.so=SharedObject.getLocal("probador");
			if (this.so!=null) {
				// cargar configuracion
				cromaCargar();
				mascaraCargar();
				cargarBlur();
				vistaCargar();
				geomCargar();
			}
		}
		
		private function away_onResize(event:Event = null):void
		{
			if (this.fer_grafica || this.fer_3d) {
				_view.width = stage.stageWidth;
				_view.height = stage.stageHeight;
			}
		}
	
		// ----------------------------------------------------------------------- away3d loading...
		protected function onLoadError(event:LoaderEvent):void
		{
			trace("Error loading: " + event.url);
		}
		private function onAssetComplete(event:AssetEvent):void
		{
			trace("Loaded " + event.asset.name + " Name: " + event.asset.name);
		}
		private function onResourceComplete(ev:LoaderEvent):void
		{
			elementsLoaded++;
			// check to see if we have all we need
			if (elementsLoaded == elementsToLoad) {
				setupScene();
			}
		}
		private function setupScene():void
		{
			trace("____________________setupAsset ("+geom.length+")");
			
			// esqueletos
			skeleton = Skeleton(AssetLibrary.getAsset("skeleton"));
			skeletons.push(skeleton);
			
			// geometrias
			hero=Mesh(AssetLibrary.getAsset("mesh"));
			hero.castsShadows = true;
			//hero.x=hero.y=hero.z=0;
			//hero.z=500;
			hero.visible=false;
			_view.scene.addChild(hero);
			geom.push(hero);
			
			/*
			// iterator de busqueda
			var iterator:AssetLibraryIterator=AssetLibrary.createIterator();
			trace("assets num: "+iterator.numAssets);
			var asset:IAsset=iterator.currentAsset;
			while (asset!=null) {
				if (asset is Skeleton) {
					skeleton=Skeleton(asset);
				}
				if (asset is Mesh) {
					hero = Mesh(asset);
				}
				asset=iterator.next();
			}
			//*/
			
			if (geom.length<geomRutas.length) {
				// cargar siguiente modelo
				trace("________ cargados ("+geom.length+"/"+geomRutas.length+")");
				elementsToLoad=1;
				elementsLoaded=0;
				AssetLibrary.load(new URLRequest(this.geomRutas[geom.length]));
			} else {
				trace("____________________ Todo cargado ____________________");
				setupAnims();
			}
			
		}
			
		private function setupAnims() {
			// debo tenerlo todo
			if (skeleton==null) {trace("NO SKELETON");return;}
			if (hero==null) {trace("NO MESH");return;}
			
			// aplicar animacion (de skeleton - cada uno del suyo) a todas nuestras geometrias
			for (var modelindex:int=0;modelindex<geom.length;modelindex++) {
			//var modelindex:int=0;
			//{
				//trace("_______________ "+modelindex);
				skeleton=(this.skeletons[modelindex] as Skeleton);
				hero=(this.geom[modelindex] as Mesh);
				
				// root pose, pose actual
				// localPoses, pose original (bind)
				// bindPoses, matrices originales (no se muy bien para que guardarlas)
				rootPose[modelindex] = new SkeletonPose();
				_localPoses = new Vector.<JointPose>(skeleton.numJoints, true);
				_bindPoses = new Vector.<Matrix3D>(skeleton.numJoints, true);
				resetNodosActualizados(skeleton.numJoints);
				
				var joint:away3d.animators.data.SkeletonJoint;
				var bind:Matrix3D;
				var parentBind:Matrix3D=new Matrix3D();
				var q1:Quaternion=new Quaternion();
				var q2:Quaternion=new Quaternion();
				
				// relleno _localPoses (y _bindPoses)
				for (var i:int=0; i<skeleton.numJoints; i++) {
					joint=skeleton.joints[i];
					//trace(i+" = "+joint.name);				
					//---------------
					bind = new Matrix3D(joint.inverseBindPose);
					bind.invert();
					_bindPoses[i] = bind;
		
					_localPoses[i]=new JointPose();
					_localPoses[i].name=joint.name;
					_localPoses[i].orientation = new Quaternion();
					if (joint.parentIndex < 0) {	// root
						_localPoses[i].orientation.fromMatrix(bind);
						_localPoses[i].translation = bind.position;
					}
					else {
						parentBind.rawData = skeleton.joints[joint.parentIndex].inverseBindPose;
		
						q1.fromMatrix(parentBind);
						q1.normalize();
						q2.fromMatrix(bind);
						q2.normalize();
						_localPoses[i].orientation.multiply(q1, q2);
						_localPoses[i].translation = parentBind.transformVector(bind.position);
					}
					//---------------
				}
				
				// crear root pose como COPIAs de localPoses
				for (var ij:int=0;ij<_localPoses.length;ij++) {
					var tp:JointPose=new JointPose();
					tp.copyFrom(_localPoses[ij]);
					tp.name=_localPoses[ij].name;
					rootPose[modelindex].jointPoses[ij]=tp;
				}
				
				// crear idle animation
				var clip:SkeletonClipNode = new SkeletonClipNode();
				clip.addFrame(rootPose[modelindex], 10); clip.addFrame(rootPose[modelindex], 10);
				clip.name = "idle";
				
				var animSet:SkeletonAnimationSet = new SkeletonAnimationSet(this.geomJointsPerVertex[modelindex]);
				animSet.addAnimation(clip);
				var animator:SkeletonAnimator = new SkeletonAnimator(animSet, skeleton);
				hero.animator = animator;
				animator.play("idle");
				
				// generate dictionary of index from this skeleton
				//createMappingForKinectJointsToMeshBones(skeleton, modelindex);		
				
				// tomar medidas base (altura/anchura)
				var jroot:Vector3D=_bindPoses[skeleton.jointIndexFromName("root")].position.clone();
				var jneck:Vector3D=_bindPoses[skeleton.jointIndexFromName("neck")].position.clone();
				var alto:Vector3D=jneck.subtract(jroot);
				this.geomBaseHeight=alto.length;
				//var jleft:JointPose=_localPoses[skeleton.jointIndexFromName("left_upper_arm")];
				//var jright:JointPose=_localPoses[skeleton.jointIndexFromName("right_upper_arm")];
				////var jright:JointPose=rootPose[modelindex].jointPoses[skeleton.jointIndexFromName("right_upper_arm")];
				//var ancho:Vector3D=jleft.translation.clone();
				var jleft:Vector3D=_bindPoses[skeleton.jointIndexFromName("left_upper_arm")].position.clone();
				var jright:Vector3D=_bindPoses[skeleton.jointIndexFromName("right_upper_arm")].position.clone();
				var ancho:Vector3D=jleft.subtract(jright);
				//ancho=ancho.subtract(jright.translation);
				this.geomBaseWidth=ancho.length;
				/*
				trace("=====================");
				trace("skeleton dimensions: ");
				trace("jroot: "+jroot.toString());
				trace("jneck: "+jneck.toString());
				trace(" alto: "+alto.toString());
				trace("       "+geomBaseHeight);
				trace("  ");
				trace(" jleft: "+jleft.toString());
				trace("jright: "+jright.toString());
				trace(" ancho: "+ancho.toString());
				trace("        "+geomBaseWidth);
				trace("  ");
				trace("=====================");
				//*/
				
				//var jroot:away3d.animators.data.SkeletonJoint=skeleton.jointFromName("root");
				//var jneck:away3d.animators.data.SkeletonJoint=skeleton.jointFromName("neck");
				//var jleft:away3d.animators.data.SkeletonJoint=skeleton.jointFromName("left_upper_arm");
				//var jright:away3d.animators.data.SkeletonJoint=skeleton.jointFromName("right_upper_arm");
				
			}
			
			// generate dictionary of index from this skeleton
			createMappingForKinectJointsToMeshBones();			

		}
		/*
		private function jointMapping(bone:String):String {
			var r:String=null;
			switch(bone.toLocaleLowerCase()) {
				case com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.NECK: r="neck"; break;
				case com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.SPINE: r="lower_spine"; break;
				case "lower_spine": r="root"; break;
				
				case "left_collar": r="left_collar"; break;
				case com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_UPPER_ARM: r="left_upper_arm"; break;
				case com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_LOWER_ARM: r="left_lower_arm"; break;
				case "left_hand": r="left_hand"; break;
				
				case "right_collar": r=""; break;
				case com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_UPPER_ARM: r=""; break;
				case com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_LOWER_ARM: r=""; break;
				case "right_hand": r=""; break;
				
				case "left_hip": r=""; break;
				case com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_UPPER_LEG: r=""; break;
				case com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_LOWER_LEG: r=""; break;
				case "leef_foot": r=""; break;
				
				case "right_hip": r=""; break;
				case com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_UPPER_LEG: r=""; break;
				case com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_LOWER_LEG: r=""; break;
				case "right_foot": r=""; break;
				default: break;
			}
			return r;
		}
		//*/
		private function createMappingForKinectJointsToMeshBones() {
			jointMapping=new Dictionary();
			//jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.HEAD] = _skeleton.jointIndexFromName("neck");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.NECK] = "neck";
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.SPINE] = "lower_spine";
			jointMapping["lower_spine"] = "root"; // spine
	
			jointMapping["left_collar"] = "left_collar";
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_UPPER_ARM] = "left_upper_arm";
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_LOWER_ARM] = "left_lower_arm";
			jointMapping["left_hand"] = "left_hand";
	
			jointMapping["right_collar"] = "right_collar";
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_UPPER_ARM] = "right_upper_arm";
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_LOWER_ARM] = "right_lower_arm";
			jointMapping["right_hand"] = "right_hand";
	
			jointMapping["left_hip"] = "left_hip";
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_UPPER_LEG] = "left_upper_leg";
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_LOWER_LEG] = "left_lower_leg";
			jointMapping["leef_foot"] = "left_foot";
	
			jointMapping["right_hip"] = "right_hip";
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_UPPER_LEG] = "right_upper_leg";
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_LOWER_LEG] = "right_lower_leg";
			jointMapping["right_foot"] = "right_foot";
		}
		/*
		private function createMappingForKinectJointsToMeshBones(_skeleton:Skeleton, modelindex:int) {
			trace("JointMapping para: "+modelindex);
			// cada bone de kinect, que joint de away le corresponde
			jointMapping[modelindex] = new Dictionary();
	
			//jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.HEAD] = _skeleton.jointIndexFromName("neck");
			jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.NECK] = _skeleton.jointIndexFromName("neck");
			jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.SPINE] = _skeleton.jointIndexFromName("lower_spine");
			jointMapping[modelindex]["lower_spine"] = _skeleton.jointIndexFromName("root"); // spine
	
			jointMapping[modelindex]["left_collar"] = _skeleton.jointIndexFromName("left_collar");
			jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_UPPER_ARM] = _skeleton.jointIndexFromName("left_upper_arm");
			jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_LOWER_ARM] = _skeleton.jointIndexFromName("left_lower_arm");
			jointMapping[modelindex]["left_hand"] = _skeleton.jointIndexFromName("left_hand");
	
			jointMapping[modelindex]["right_collar"] = _skeleton.jointIndexFromName("right_collar");
			jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_UPPER_ARM] = _skeleton.jointIndexFromName("right_upper_arm");
			jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_LOWER_ARM] = _skeleton.jointIndexFromName("right_lower_arm");
			jointMapping[modelindex]["right_hand"] = _skeleton.jointIndexFromName("right_hand");
	
			jointMapping[modelindex]["left_hip"] = _skeleton.jointIndexFromName("left_hip");
			jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_UPPER_LEG] = _skeleton.jointIndexFromName("left_upper_leg");
			jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_LOWER_LEG] = _skeleton.jointIndexFromName("left_lower_leg");
			jointMapping[modelindex]["leef_foot"] = _skeleton.jointIndexFromName("left_foot");
	
			jointMapping[modelindex]["right_hip"] = _skeleton.jointIndexFromName("right_hip");
			jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_UPPER_LEG] = _skeleton.jointIndexFromName("right_upper_leg");
			jointMapping[modelindex][com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_LOWER_LEG] = _skeleton.jointIndexFromName("right_lower_leg");
			jointMapping[modelindex]["right_foot"] = _skeleton.jointIndexFromName("right_foot");
		
			/*
			for (var k:Object in jointMapping[modelindex]) {
				var value = jointMapping[modelindex][k];
				var key = k;
				trace("  "+key+" => "+value);
			}
			//*/
		//}
		//*/
		
		// ---------------------------------------------------------------------------------- ESCENA
		public function escenaEntrar() {
			if (!Capabilities.isDebugger) Mouse.hide();
			stage.focus=this;
		}
		public function escenaSalir() {}
		
		private function away_onEnterFrame(e:Event):void
		{			
			//trace("App frame draw");
			//if (this.fer_croma) {
				processCroma();	// componer siempre desde la camara (con o sin croma)
			//}
			if (this.fer_3d && hero!=null) {
				//offsetScaleX=20;
				//offsetScaleY=20;
				if (currentUser!=null) {
					// actualizar y mostrar geomtria
					updateKinect(currentUser);
					if (modelo<rootPose.length) updateSkeleton(geom[modelo],rootPose[modelo], skeletons[modelo]);
					hero.visible=true;
					/*
					updateSkeleton(geom[0],rootPose[0], skeletons[0]);
					updateSkeleton(geom[1],rootPose[1], skeletons[1]);
					updateSkeleton(geom[2],rootPose[2], skeletons[2]);
					//*/

				} else {
					// ocultar geometria
					if (hero!=null) hero.visible=false;
				}
			}
			if (this.fer_over) {
				updateMano();
			}
			if (this.fer_grafica || this.fer_3d) {
				if (this.calibrando) {
					if (hideGeom && hero!=null) {
						hero.visible=false;
						cajasContainer.visible=false;
					} else {
						cajasContainer.visible=true;
					}
				}
				_view.render();
			}
			if (this.calibrando) {
				fftrace();
				fftrace("croma: ________________________");
				fftrace("    rojo = "+rr);
				fftrace("   verde = "+rg);
				fftrace("    azul = "+rb);
				fftrace("  umbral = "+rr);
				fftrace("camara: _______________________");
				fftrace("       x = "+_view.camera.x.toFixed(2));
				fftrace("       y = "+_view.camera.y.toFixed(2));
				fftrace("       z = "+_view.camera.z.toFixed(2));
				fftrace("     fov= "+(_view.camera.lens as PerspectiveLens).fieldOfView);
				fftrace("mascara: ______________________");
				fftrace("       x = "+mascaraOffsetX.toFixed(2));
				fftrace("       y = "+mascaraOffsetY.toFixed(2));
				fftrace("   scale = "+mascaraScale.toFixed(2));
				fftrace("    blur = "+blur.blurX.toFixed(2));
				fftrace("geom scale: ___________________");
				fftrace("      sx = "+this.geomScaleX.toFixed(2));
				fftrace("      sy = "+this.geomScaleY.toFixed(2));
				fftrace("      sz = "+this.geomScaleZ.toFixed(2));
				if (fer_autoScale) {
					fftrace("   autoX = "+this.offsetScaleX.toFixed(2));
					fftrace("   autoY = "+this.offsetScaleY.toFixed(2));
				}
				fftrace("_______________________________");
			}
		}
		
		public function playerEnters(event:UserEvent=null) {
			if (currentUser==null) {
				trace("User Enters", event.users);
				currentUser=event.users[0];
			}
		}
		
		public function playerExits(event:UserEvent=null) {
			for each (var u:User in event.users) {
				if (u==currentUser) {
					currentUser=null;
					trace("User Exits", event.users);
				}
			}
		}
		
		// ------------------------------------------------------ update mano (over)
		private function updateMano() {
			if (this.estado>=this.ESTADO_FOTO) return;
			if (currentUser!=null) {
				// mover raton (para evitar salvapantallas)
				if (mce.connected) {
					mce.writeUTFBytes("mouse:mm,"+(mceDir?"+":"-")+"100,0\n");
					mce.flush();
					mceDir=!mceDir;
				}
				
				var antes:Boolean=mano.visible;
				var derecha:Boolean=true;
				
				var umbral:Number=Math.abs(currentUser.rightShoulder.position.world.x-currentUser.leftShoulder.position.world.x)*1.25;
				var actualR:Number=currentUser.torso.position.world.z-currentUser.rightHand.position.world.z;
				var actualL:Number=currentUser.torso.position.world.z-currentUser.leftHand.position.world.z;
				
				if (actualR>umbral) {
					mano.visible=true;
					derecha=true;
				} else if (actualL>umbral) {
					mano.visible=true;
					derecha=false;
				} else mano.visible=false;
				
				if (mano.visible) {
					var p:Point;
					if (derecha) p=currentUser.rightHand.position.rgb;
					else p=currentUser.leftHand.position.rgb;
					
					p.x=this.fer_escalar*bmd.width*p.x/640;
					p.y=this.fer_escalar*bmd.height*p.y/480;
					p=invtrans(p.x,p.y);
					mano.x=p.x;
					mano.y=p.y;
				
					// comprobar pulsaciones
					if (manoPulsando==null) {
						// test entrar en zona
						if (mano.hitTestObject(botonFoto)) {
							manoPulsando=botonFoto;
							manoTimer.reset();
							manoTimer.start();
							mano.play();
							botonFoto.play();
						}
						if (mano.hitTestObject(botonFondo)) {
							manoPulsando=botonFondo;
							manoTimer.reset();
							manoTimer.start();
							mano.play();
							botonFondo.play();
						}
					} else {
						// test salir de zona
						if (!mano.hitTestObject(manoPulsando)) {
							manoPulsando=null;
							manoTimer.stop();
							mano.gotoAndStop(1);
							botonFoto.gotoAndStop(1);
							botonFondo.gotoAndStop(1);
						}
					}
					
				} else {
					if (antes) {
						// desaparece, anula pulsaciones
						manoPulsando=null;
						manoTimer.stop();
						mano.gotoAndStop(1);
						botonFoto.gotoAndStop(1);
						botonFondo.gotoAndStop(1);
					}
				}
			} else {
				// sin jugador no hay mano
				manoPulsando=null;
				manoTimer.stop();
				mano.visible=false;
				mano.gotoAndStop(1);
				botonFoto.gotoAndStop(1);
				botonFondo.gotoAndStop(1);
			}
		}
		private function manoTimerComplete(e:Event=null) {
			manoTimer.stop();
			if (this.estado!=this.ESTADO_ESCENA) return;
			
			var accion:String="";
			if (manoPulsando==botonFoto) accion="foto";
			if (manoPulsando==botonFondo) accion="fondo";
			manoPulsando=null;
			mano.visible=false;
			mano.gotoAndStop(1);
			botonFoto.gotoAndStop(1);
			botonFondo.gotoAndStop(1);
			
			if (accion=="foto") botonFotoClick();
			if (accion=="fondo") botonFondoClick();
		}
		
		
		// ------------------------------------------------------ update skeleton (3d)
		// waist,torso,neck,head,left_shoulder,left_elbow,left_wrist,left_hand,right_shoulder,right_elbow,right_wrist,right_hand,left_hip,left_knee,left_ankle,left_foot,right_hip,right_knee,right_ankle,right_foot
		private var orientaciones:Object={//kinect_bone : [X kinj.Ini,kinj.Fin, Y kinj.Ini,kinj.Fin, true=Y/false=Z, kinj.pos.base
										  "lower_spine":["right_shoulder","left_shoulder","torso","waist",false, "waist"], // mueve root
										  
										  //"spine":["torso","waist","left_shoulder","right_shoulder",false, "torso"],
										  "neck":["head","neck","left_shoulder","right_shoulder",false, "neck"],
										  
										  "left_collar":["right_shoulder","neck","torso","waist",false, "right_shoulder"],
										  "right_collar":["left_shoulder","neck","torso","waist",false, "left_shoulder"],
										  
										  "left_upper_arm":["right_elbow","right_shoulder","right_wrist","right_elbow",true, "right_shoulder"],
										  "left_lower_arm":["right_wrist","right_elbow","right_shoulder","right_elbow",true, "right_elbow"],
										  "left_hand":["right_hand","right_wrist","right_shoulder","right_elbow",true,"right_hand"],
										  "right_upper_arm":["left_elbow","left_shoulder","left_elbow","left_wrist",true, "left_shoulder"],
										  "right_lower_arm":["left_wrist","left_elbow","left_elbow","left_shoulder",true, "left_elbow"],
										  "right_hand":["left_hand","left_wrist","left_elbow","left_shoulder",true,"left_hand"],
										  
										  "left_hip":["right_hip","waist","right_hip","left_hip",false, "right_hip"],
										  "right_hip":["left_hip","waist","left_hip","right_hip",false, "left_hip"],
										  
										  "left_upper_leg":["right_knee","right_hip","right_hip","left_hip",false, "right_hip"],
										  "left_lower_leg":["right_ankle","right_knee","right_hip","left_hip",false, "right_knee"],
										  "right_upper_leg":["left_knee","left_hip","left_hip","right_hip",false, "left_hip"],
										  "right_lower_leg":["left_ankle","left_knee","left_hip","right_hip",false, "left_knee"],
										  "none":[]
										  }
		private function updateKinect(u:User) {
		//private function updateSkeleton(skel:SkeletonPose, u:User, skeleton:Skeleton, jointMapping:Dictionary) {
			
			var boxindex:int=0;
			if (u==null || u.skeletonBones==null) return; // esperar a tener usuario con esqueleto
			
			kinectPose=new Dictionary();
			// por cada hueso kinect (orientacion)
			for each (var ub:com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone in u.skeletonBones) {
				//trace("bone: "+ub.name+" [descendiente de:"+ub.parentBoneName+"]");
				// si el bone controla algo (está en nuestra tabla de bones-kinect que controlan joins-away)
				if (jointMapping[ub.name]!=undefined) {
					//// obtener joinPose a afectar
					//var sji:Number=jointMapping[ub.name];
					//if (sji==-1) continue; 	// si el join a controlar no existe en este esqueleto, saltar
					
					if (orientaciones[ub.name]==undefined) continue;
					
					// join a controlar
					//var sjp:JointPose=skel.jointPoses[sji];
					//trace(" controla: "+sjp.name)
					////obtener el bindPose (orientacion original)
					////var sjb:JointPose=_localPoses[sji];
					
					// orientacion para este hueso
					var orientacion:Array=orientaciones[ub.name];
					// obtener puntos de referencia					
					// direccion principal
					var iniX:Vector3D=u.skeletonJoints[u.skeletonJointNameIndices[orientacion[0]]].position.world;
					var finX:Vector3D=u.skeletonJoints[u.skeletonJointNameIndices[orientacion[1]]].position.world;
					// eje secundario
					var iniY:Vector3D=u.skeletonJoints[u.skeletonJointNameIndices[orientacion[2]]].position.world;
					var finY:Vector3D=u.skeletonJoints[u.skeletonJointNameIndices[orientacion[3]]].position.world;
					// posicion base
					var base:Vector3D=u.skeletonJoints[u.skeletonJointNameIndices[orientacion[5]]].position.world;
					
					// obtener direccion
					var q:Quaternion=calcOrient(iniX,finX,iniY,finY,orientacion[4]); // 1er eje siempre X, 2o eje (true=Y // false=z)
					
					// obtener matriz de transformacion final (incluida posicion)
					var finalMat:Matrix3D=q.toMatrix3D();
					finalMat.appendTranslation(base.x, base.y, base.z);
					
					// almacenar en pose calculada desde kinect
					kinectPose[jointMapping[ub.name]]=finalMat;
					
					/*
					// mostrar ejes al inicio y fin del bone
					cajas[boxindex].transform=q.toMatrix3D();
					cajas[boxindex].position=base;
					cajas[boxindex].visible=true;
					boxindex++;
					//*/
				}
			}
			
			if (fer_autoScale) {
				//trace(" medir kinect");
				// tomar medidas skeleto actual (altura/anchura)
				var jroot:Vector3D=u.skeletonJoints[u.skeletonJointNameIndices["waist"]].position.world;
				var jneck:Vector3D=u.skeletonJoints[u.skeletonJointNameIndices["neck"]].position.world;
				var alto:Vector3D=jneck.clone();
				alto=alto.subtract(jroot);
				var currentHeight:Number=alto.length;
				var jleft:Vector3D=u.skeletonJoints[u.skeletonJointNameIndices["left_shoulder"]].position.world;
				var jright:Vector3D=u.skeletonJoints[u.skeletonJointNameIndices["right_shoulder"]].position.world;
				var ancho:Vector3D=jleft.clone();
				ancho=ancho.subtract(jright);
				var currentWidth:Number=ancho.length;
						
				offsetScaleX=(currentWidth/geomBaseWidth);
				offsetScaleY=(currentHeight/geomBaseHeight);
				offsetScaleZ=(offsetScaleX+offsetScaleY)*0.5;
				
				offsetScaleX=offsetScaleX*this.geomScaleX;
				offsetScaleY=offsetScaleY*this.geomScaleY;
				offsetScaleZ=offsetScaleZ*this.geomScaleZ;
			} else {
				offsetScaleX=this.geomScaleX;
				offsetScaleY=this.geomScaleY;
				offsetScaleZ=this.geomScaleZ;
			}
			
			/*
			trace("=====================");
			trace("KINECT dimensions: ");
			trace("jroot: "+jroot.toString());
			trace("jneck: "+jneck.toString());
			trace(" alto: "+alto.toString());
			trace("       "+currentHeight);
			trace("  ");
			trace(" jleft: "+jleft.toString());
			trace("jright: "+jright.toString());
			trace(" ancho: "+ancho.toString());
			trace("        "+currentWidth);
			trace("=====================");
			trace("cur: "+currentWidth+" / bind: "+geomBaseWidth);
			trace("scaleX: "+offsetScaleX);
			trace("   ");
			trace("cur: "+currentHeight+" / bind: "+geomBaseHeight);
			trace("scaleY: "+offsetScaleY);
			trace("=====================");
			trace("  ");
			trace("  ");
			//*/
		}
		private function updateSkeleton(g:Mesh, skel:SkeletonPose, skeleton:Skeleton) {
			// tenemos calculadas las transformaciones destino
			// ahora toca aplicarlas (en orden de padre a hijos)
			resetNodosActualizados();
			hero=g;
			hero.visible=true;
		
			boxindex=0;
			// por cada joint-away ya calculado de kinect
			for (var b in this.kinectPose) {
				//trace("afectando a "+b+" : "+kinectPose[b]);
					actualizarNodo(b, skel,skeleton);
			}			

		}
		
		private var nodosActualizados:Dictionary;
		private function resetNodosActualizados(numJoints=1) {
			nodosActualizados=new Dictionary();
		}
		var boxindex:int=0;
		private function actualizarNodo(name:String, skel:SkeletonPose, skeleton:Skeleton) {
			// ignorar si no necesita actualizacion (p.ej: right_collar no se ajusta desde kinect)
			if (kinectPose[name]==undefined) return;
			
			// obtener index de joinPose a afectar
			var index:int=skeleton.jointIndexFromName(name);
				
			// ignorar si fuera de rango
			if (index>=skel.jointPoses.length) return;
			
			var joint:away3d.animators.data.SkeletonJoint=(skeleton.joints[index] as away3d.animators.data.SkeletonJoint);
			
			// ignorar si ya actualizado
			if (nodosActualizados[joint.name]!=undefined) return;
			
			//trace("actualizar nodo: "+name+" pose:"+kinectPose[name]);
			
			// hueso padre (para comprobar si ya está actualizado
			var pindex:int=joint.parentIndex;
			if (pindex!=-1) {
				var pjoint:away3d.animators.data.SkeletonJoint=skeleton.joints[pindex];
				if (nodosActualizados[pjoint.name]==undefined) {
					// tiene padre, pero no está actualizado
					actualizarNodo(pjoint.name, skel, skeleton);
				}
			}
			// no tenia padre, ya estaba actualizado... o se acaba de actualizar
			
			// actualizo el actual			
			// transformacion destino (incluye posicion)
			var mat:Matrix3D=kinectPose[name];
			// aplicar transformacion (de global-kinect sobre local-away)
			actualizarOrientar(index,mat,skel,skeleton);
			
			// marcar como actualizado
			nodosActualizados[joint.name]=true;
		}
		private function actualizarOrientar(indexActual:int, global:Matrix3D, skel:SkeletonPose, skeleton:Skeleton) {
			if (indexActual!=-1) {
				var index:int=indexActual;
				var matToGlobal:Matrix3D=new Matrix3D(); // inicialmente identidad
				
				
				// transformacion local - inicial
				var jp:JointPose=skel.jointPoses[index];
				var sj:away3d.animators.data.SkeletonJoint=skeleton.joints[index];
				//trace("  orientando: "+jp.name+" ("+sj.name+")");
				
				var q:Quaternion;
				var t:Vector3D;
				var m:Matrix3D=new Matrix3D();
				
				while (sj.parentIndex!=-1) {
					index=sj.parentIndex;
					jp=skel.jointPoses[index];
					sj=skeleton.joints[index];
					
					q=jp.orientation;
					t=jp.translation;
					m=q.toMatrix3D();
					m.appendTranslation(t.x,t.y,t.z);
					
					matToGlobal.append(m);
				}
				
				// tengo matrix que pasa de local a global (matToGlobal)
				var matToLocal:Matrix3D=new Matrix3D();
				matToLocal.copyFrom(matToGlobal);
				matToLocal.invert();
				// tengo matrix que pasa de global a local (matToLocal)
				
				// si agarro la pose global (kinect)
				m.copyFrom(global);
				// y la multiplico por la matrix de global->local (inversa de local->global)
				m.append(matToLocal);
				// tengo (en em) la orientacion en local
				
				// aplicar nueva transformacion al jointPose indicado
				jp=skel.jointPoses[indexActual];	// recuperar el indicado
				sj=skeleton.joints[indexActual];	// recuperar el hueso (para buscar padre)
				jp.orientation.fromMatrix(m);
				
				//*
				// mostrar ejes al inicio y fin del bone
				cajas[boxindex].transform=global.clone();
				cajas[boxindex].visible=true;
				boxindex++;
				//*/
			
				//if (jp.name=="root") jp.translation=m.position;  // solo al root
				//if (jp.name=="root") hero.position=m.position;  // solo al root
				/*
				if (fer_3dbrazos) {
					if (jp.name=="left_lower_arm") { // || jp.name=="right_lower_arm") {
						// posicionar codos
						//hero.scaleX=geomScaleX;
						//hero.scaleY=geomScaleY;
						//hero.scaleZ=geomScaleZ;;
						//m.appendTranslation(0,40*geomScaleY,0);
						//jp.translation=m.position.clone();
						//jp.translation=new Vector3D(jp.translation.x-0.2,jp.translation.y,jp.translation.z);
						//jp.translation=new Vector3D(jp.translation.x/hero.scaleX,jp.translation.y/hero.scaleY,jp.translation.z/hero.scaleZ);
						//jp.translation=new Vector3D(-m.position.x/hero.scaleX,0,0);
						
						var jpp:JointPose=skel.jointPoses[sj.parentIndex];
						
						fftrace("root: "+hero.position.x.toFixed(2)+", "+hero.position.y.toFixed(2)+", "+hero.position.z.toFixed(2));
						
						fftrace("poss: "+jp.translation.x.toFixed(2)+", "+jp.translation.y.toFixed(2)+", "+jp.translation.z.toFixed(2));
						var v:Vector3D=m.position.clone();
						v.subtract(jp.translation.clone());
						fftrace("diff: "+v.x.toFixed(2)+", "+v.y.toFixed(2)+", "+v.z.toFixed(2));
						
						fftrace("parn: "+jpp.translation.x.toFixed(2)+", "+jpp.translation.y.toFixed(2)+", "+jpp.translation.z.toFixed(2));
						v=m.position.clone();
						v.subtract(jpp.translation.clone());
						fftrace("difp: "+v.x.toFixed(2)+", "+v.y.toFixed(2)+", "+v.z.toFixed(2));
						
						//var tm:Matrix3D=m.clone();	// supuestamente local, con pos
						var tm:Matrix3D=jp.orientation.toMatrix3D();
						tm.position=jp.translation.clone();
						tm.append(matToGlobal);		// supuestamente volvemos al globa (igual que global)
						// mostrar ejes al inicio y fin del bone
						cajas[boxindex].transform=tm.clone();
						cajas[boxindex].visible=true;
						boxindex++;
					}
				}
				//*/
				if (jp.name=="root") { // solo al root
					hero.scaleX=new Number(offsetScaleX.valueOf());
					hero.scaleY=new Number(offsetScaleY.valueOf());
					hero.scaleZ=new Number(offsetScaleZ.valueOf());
					
					hero.position=global.position.clone();
				}
				
			}
		}
		
		private function calcOrient(iniX:Vector3D, finX:Vector3D,iniY:Vector3D, finY:Vector3D, onY:Boolean=true):Quaternion {
			var u:Vector3D=finX.subtract(iniX); // principal
			var v:Vector3D;
			var w:Vector3D;
			if (onY) {
				v=finY.subtract(iniY); // secundario en Y
			} else {
				w=finY.subtract(iniY); // secundario en Z
			}
			
			/*
			// opcion por Quaternion directamente
			//vec3 w = cross(u, v);
			var w:Vector3D=u.crossProduct(v);
			//quat q = quat(dot(u, v), w.x, w.y, w.z);
			var q:Quaternion=new Quaternion(w.x,w.y,w.z,u.dotProduct(v));
			//q.w += length(q);
			q.w+=q.magnitude;
			// normalize(q);
			q.normalize();
			return q;
			//*/
			
			/*
			// opcion por matrices
			Vec3 xaxis = Vec3::Cross(up, direction);
			xaxis.normalizeFast();
	
			Vec3 yaxis = Vec3::Cross(direction, xaxis);
			yaxis.normalizeFast();
	
			column1.x = xaxis.x;
			column1.y = yaxis.x;
			column1.z = direction.x;
	
			column2.x = xaxis.y;
			column2.y = yaxis.y;
			column2.z = direction.y;
	
			column3.x = xaxis.z;
			column3.y = yaxis.z;
			column3.z = direction.z;
			//*/
			
			// opcion por vectores
			//Matrix3x3 M;
			var m:Matrix3D=new Matrix3D();
			//M.X = normalise( X );  
			u.normalize();
			m.copyRowFrom(0,u);	// 0=x
			if (onY) {
				//M.Z = normalise( cross_product(X,Y) );
				w=u.crossProduct(v);
				w.normalize();
				m.copyRowFrom(2,w);	// 2=z
				//M.Y = normalise( cross_product(M.Z,X) );
				v=w.crossProduct(u);
				v.normalize();
				m.copyRowFrom(1,v); // 1=v; (regenerado, para asegurar ortonormal
			} else {
				v=u.crossProduct(w);
				v.normalize();
				m.copyRowFrom(1,v);
				w=v.crossProduct(u);
				w.normalize();
				m.copyRowFrom(2,w);
			}
			m.invert();
			//return M;
			var q:Quaternion=new Quaternion();
			q.fromMatrix(m);
			return q;
			
		}

		// ------------------------------------------------------------------------- KINECT IMG
		public function camRgbUpdate(e:CameraImageEvent) {
			//trace("Kinect Image received");
			bmdOrig=e.imageData; // me guardo la ultima imagen recibida (para procesar mas tarde)
			
			// retardo en imagen de camara
			//oldcam.push(e.imageData.clone());
			//if (oldcam.length>oldframes) {
			//	var bd:BitmapData=(oldcam.shift() as BitmapData);
			//	camara.bitmapData=bd.clone();
			//	bd.dispose();
			//}
		}
		
		public function camMaskUpdate(e:UserEvent) {
			if (currentUser==null) return;
			for each(var u:User in e.users) {
				if (u.userID==currentUser.userID) { // solo actualizar datos del jugador activo
					if (u.userMaskData!=null) {
						bmdMask=u.userMaskData.clone(); // sobreescribir por completo
					}
					break;
				}
			} // for each user
		}
		
		// ------------------------------------------------------------------------- CROMA
		private var rr:Number=0, rg:Number=0, rb:Number=0, umbral:Number=32; // color ref y umbral
		private var pval:uint, oval:uint;	// pixel entrada / pixel salida
		private var aacum:uint; // acumulado de alpha -alrededores- para suavizar
		private var stride:uint; // num pixels salto de linea
		private var ia:Number, ir:Number, ig:Number, ib:Number;	// valores de entrada (Desglosado)
		private var cr:Number, cg:Number, cb:Number; 			// copias de entrada (para convertir a HSV)
		private var i:Number;	// bucle
		private var p:Vector.<uint>, plen:Number;	// pixels bytearray, y length
		private var dist:Number, temp:Number; 		// distancia (parcial) / acumulado
		private var blur:BlurFilter;
		private var addMask:Sprite=new Sprite();
		private var lastCaraX:Number=NaN;
		private var lastCaraY:Number=NaN;
		private var lastCaraD:Number=NaN;
		public function processCroma() {
			//trace("Process Chroma");
			if (bmdOrig==null) return; // esperar a tener "al menos" el primer frame

			bmd=bmdOrig.clone();	// para referencia a la hora de pulsar-arrastrar (elegir color croma)
			
			if (camara!=null) camara.bitmapData=bmd; // update bitmap data
			
			// CROMA
			if (this.fer_croma || this.fer_cromaKinect) {
				if (this.fer_cromaKinect) {  // croma por kinect					
					if (this.currentUser) { // tengo usuario (uso mascara)
						if (bmdMask!=null) {
							if (bmdMask2==null) bmdMask2=new BitmapData(bmdMask.width*2,bmdMask.height*2,true,0);
							bmdMask2.fillRect(bmdMask2.rect,0);	// inicializao en negro -transparente-
							// escalo croma-kinect a tamaño imagen-kinect
							bmdMask2.draw(bmdMask,maskMat,null,null,null,true);
							
							if (this.fer_cromaHuevo) {
								// dibujo un ovalo en la cabeza (para asegurar croma en pelo)
								if (currentUser!=null && currentUser.hasSkeleton) {
									var h:Point=currentUser.head.position.depth;
									var n:Point=currentUser.neck.position.depth;
									//trace("head: "+h.toString()+"   conf: "+currentUser.head.positionConfidence);
									//trace("neck: "+n.toString()+"   conf: "+currentUser.neck.positionConfidence);
									h.x*=(2/this.fer_escalar);h.y*=(2/this.fer_escalar);
									n.x*=(2/this.fer_escalar);n.y*=(2/this.fer_escalar);
									var d:Number=h.subtract(n).length;
									var px:Number=((h.x*0.5+n.x*0.5));
									var py:Number=((h.y*0.5+n.y*0.5));
									if (isNaN(lastCaraX) || Math.abs(lastCaraX-px)<lastCaraX*0.5 ||
										isNaN(lastCaraY) || Math.abs(lastCaraY-py)<lastCaraY*0.5) {
										lastCaraX=px;lastCaraY=py;
									}
									//if (isNaN(lastCaraY) || Math.abs(lastCaraY-py)<lastCaraY*0.5) lastCaraY=py;
									if (isNaN(lastCaraD) || Math.abs(lastCaraD-d)<lastCaraD*0.625) lastCaraD=d;
								} else {
									lastCaraX=NaN;
									lastCaraY=NaN;
									lastCaraD=NaN;
								}
								if (!isNaN(lastCaraX) && !isNaN(lastCaraY) && !isNaN(lastCaraD)) {
									addMask.graphics.clear();
									addMask.graphics.beginFill(0xFFFFFF);
									addMask.graphics.drawCircle(lastCaraX,lastCaraY,0.5*lastCaraD);
									bmdMask2.draw(addMask,null,null,null,null,true);
								}
								//trace(lastCaraX+", "+lastCaraY+" : "+lastCaraD);
								//trace("_____");
							}
							
							// aplico blur al croma original-kinect
								if (blur==null) cargarBlur();
								bmdMask2.applyFilter(bmdMask2,bmdMask2.rect,new Point(0,0),blur);
							// aplico croma-kinect a imagne-kinect
							bmd.copyChannel(bmdMask2,bmdMask2.rect,new Point(0,0),BitmapDataChannel.ALPHA,BitmapDataChannel.ALPHA);
							//bmd.copyChannel(bmdMask2,bmdMask2.rect,new Point(0,0),BitmapDataChannel.RED,BitmapDataChannel.ALPHA);
						}
					} else { // sin usuario
						// (no aplico mascara, dejo camara tal cual)
						// ...
						// o aplico mascar completa (para ver todo fondo)
						if (fer_cromaMostrarFondo)
							bmd.colorTransform(bmd.rect,new ColorTransform(1,1,1,0));
					}
					
				}
				
				if (this.fer_croma) {// || this.fer_cromaKinect) {
					// alpha por color (o suavizado)
					p=bmd.getVector(bmd.rect);
					plen=p.length;
					stride=bmd.width;
				}

				if (this.fer_croma) {
					if (this.currentUser!=null) { // teniendo usuario (aplico croma)
						for (i=0;i<plen;i++) {
							// decomponer entrada
							pval=p[i];	// pixel de imagen
							ia=(pval>>24)&0xFF; // shift Argb
							cr=ir=(pval>>16)&0xFF; // shift aRgb
							cg=ig=(pval>>8)&0xFF; // shift arGb
							cb=ib=(pval)&0xFF; // noshift nedded argB
							
							// trabajar en HSV
							rgb2hsvReturn=rgb2hsv(cr,cg,cb);
							cr=rgb2hsvReturn.r;
							cg=rgb2hsvReturn.g;
							cb=rgb2hsvReturn.b;
							
							// calcular distancia a color de refencia
							dist=0;
							temp=(cr-rr); temp*=temp;
							dist+=temp;
							temp=(cg-rg); temp*=temp;
							dist+=temp;
							temp=(cb-rb); temp*=temp;
							dist+=temp;
							
							temp=(umbral*umbral);
						
							// determinar si visible o mascara
							// diferente=visible / parecido=invisible (eliminar el color seleccionado)
							if (dist>temp) ia=255; else ia=0;
			
							// componer salida
							oval=(ia<<24)+(ir<<16)+(ig<<8)+(ib);
							p[i]=oval; // store final value
							
							if (this.fer_cromaMedio) {
								// aplicar mismo alfa al siguiente/linea inferior
								if ((i+1)<plen) p[i+1]=(p[i+1]&0x00FFFFFF)+(ia<<24);
								if ((i+stride)<plen) p[i+stride]=(p[i+stride]&0x00FFFFFF)+(ia<<24);
								if ((i+stride+1)<plen) p[i+stride+1]=(p[i+stride+1]&0x00FFFFFF)+(ia<<24);
								// analizar la mitad de lineas
								if ((i%stride)==0) {
									// estoy en el primer pixel de linea
									if (((i/stride)%2)!=0) {
										//  i/stride=num linea
										//  me quedo en las pares (0,2,4... que tienen resto 0)
										//  si estoy en impar... salto a la siguiente linea (+stride)
										i+=stride;
									}
								}
								// analizar la mitad de pixels (en linea)
								i++;
							}
						} // bucle por pixels
					} else { // sin usurios
						// (no aplico mascara, dejo camara tal cual)
						// ...
						// o aplico mascar completa (para ver todo fondo)
						if (fer_cromaMostrarFondo)
							bmd.colorTransform(bmd.rect,new ColorTransform(1,1,1,0));
							//bmd.colorTransform(bmd.rect,new ColorTransform(1,1,1,0));
					}
				}
				
				if (this.fer_cromafino) {
					if (this.currentUser==null) {
						// si no tengo usuario no he aplicado mascara
						// (o toda completa... pero no por croma)
						// no es necesario "afinar" el croma
					} else {
						// dar segunda vuelta... suavizando y eliminando vacios
						for (i=stride+1;i<(plen-stride-1);i++) {
							aacum=0;
							aacum+=(p[i-stride-1]>>24)&0xFF;
							aacum+=(p[i-stride]>>24)&0xFF;
							aacum+=(p[i-stride+1]>>24)&0xFF;
							aacum+=(p[i-1]>>24)&0xFF;
							aacum+=(p[i+1]>>24)&0xFF;
							aacum+=(p[i+stride-1]>>24)&0xFF;
							aacum+=(p[i+stride]>>24)&0xFF;
							aacum+=(p[i+stride+1]>>24)&0xFF;
							// dividir entre los 8pixeles tomados (>>3)
							aacum>>=3;
							// modificar alfa final
							pval=p[i];	// pixel de imagen
							p[i]=(pval&0x00FFFFFF)+(aacum<<24);  // color-original + alfa nuevo
						}
					}
				} // croma fino
				
				if (this.fer_croma) { // || this.fer_cromaKinect) {
					if (this.currentUser==null) {
						// si no tengo usuario no he aplicado mascara
						// (o toda completa... pero no por croma)
						// no es necesario "afinar" el croma
					} else {
						// actualizar bitmap con el croma
						bmd.setVector(bmd.rect,p);
					}
				}
					
			} // fer_croma
			
			// COMPOSICION FINAL
			if (bmd2==null) bmd2=new BitmapData(1024,1024,true,0x000000);
				
			// COMPONER CON EL FONDO (Video)
			if (this.fer_video) {
				// el video ya esta girado... no necesita escalado ni rotacion
				bmd2.draw(video,null,null,null,null,true); // escalar video
			} else {
				// poner un fondo liso (rojo)
				//bmd2.fillRect(bmd2.rect,0xFF0000);
				var fondoFijo:BitmapData=Cast.bitmapData(fondosFijos[modelo]);
				var fondoFijoMatrix:Matrix=new Matrix();
				fondoFijoMatrix.scale(1024/fondoFijo.width,1024/fondoFijo.height);
				bmd2.draw(fondoFijo,fondoFijoMatrix);
			}
			
			// COMPONER CON LA CAMARA (web)
			if (bmd2m==null) {
				bmd2m=new Matrix();
				//bmd2m.scale(1024/bmd.width,1024/bmd.height);
				//bmd2m.scale(1024/bmd.height,1024/bmd.height);
				bmd2m.scale(1280/bmd.height,1280/bmd.height);
				bmd2m.rotate(-Math.PI*0.5);
				bmd2m.scale(1024/1280,1024/720);
				bmd2m.translate(0,1024+320*(1024/480)); // 640*(1024/480)
			}

			bmd2.draw(bmd,bmd2m,null,null,null,true);	// escalar camara
				
			// SUBIR A GRAFICA
			if (this.fer_grafica) {
				if (_view.background==null) {
					bmd2t=new BitmapTexture(bmd2,false);
					_view.background=bmd2t;
				}
				bmd2t.invalidateContent();	// subir textura
			}
			
		}
		
		// -------------------------------------------------------------------------------- APP IN-OUT
		public function appOut(e:Event) {
			sonidos.gotoAndStop("silencio");
		}
		public function appIn(e:Event) {
			if (!this.fer_video) sonidos.gotoAndStop(this.modelo+1);
		}
		
		// ---------------------------------------------------------------------------------- BOTONES
		public function botonFondoClick() {
			trace(">>>>> FONDO >>>>");
			this.modelo++;
			if (this.modelo>=this.geom.length) modelo=0;
			
			if (this.fer_video) { // lanzar video de fondo
				ns.play(this.fondos[this.modelo]);
			} else {	// fondo fijo-lanzar audio
				sonidos.gotoAndStop(this.modelo+1);
			}
			if (this.fer_3d) {
				// cambiar geometria
				if (hero!=null) hero.visible=false;
				hero=this.geom[modelo];
				hero.visible=true;
				//skeleton=this.skeletons[modelo];
			}
		}
		public function botonFotoClick() {
			trace(">>>>> FOTO >>>>");
			this.gotoEstado(this.ESTADO_FOTO);
		}
		
		// ---------------------------------------------------------------------------------- FOTO
		private var lastFoto:BitmapData;
		public function fotoEntrar() {
			// desactivar mano
			manoPulsando=null;
			manoTimer.stop();
			mano.visible=false;
			mano.gotoAndStop(1);
			//botonFoto.gotoAndStop(1);
			//botonFondo.gotoAndStop(1);
			Mouse.show();
			lastFoto=null;
		}
		public function fotoSalir() {}
		
		public function capturarFoto() {
			// CAPTURAR IMAGEN DE 3D
			trace("CAPTURAR IMAGEN DE 3D");
			var temp:BitmapData = new BitmapData(1280,720); //stage.stageWidth, stage.stageHeight, true, 0x000000);
			_view.renderer.queueSnapshot(temp);
			_view.render();
			
			temp.draw(faldon);
			lastFoto=new BitmapData(temp.height,temp.width);
			var m:Matrix=new Matrix();
			m.rotate(Math.PI*0.5);m.tx=temp.height;
			lastFoto.draw(temp,m,null,null,null,true);
			temp.dispose();
			
			this.gotoEstado(this.ESTADO_DATOS);
		}
		
		// ---------------------------------------------------------------------------------- DATOS
		public var datosDireccion:String="";
		public function datosEntrar() {
			datosDireccion="";
			tDireccion.text="";
			bAceptar.addEventListener(MouseEvent.CLICK, datosAceptarClick);
			bCancelar.addEventListener(MouseEvent.CLICK, datosCancelarClick);
			stage.focus=tDireccion;
		}
		public function datosSalir() {
			datosDireccion=tDireccion.text;
		}
		
		public function datosAceptarClick(e:Event=null) {
			if (tDireccion.text!="") {
				this.gotoEstado(this.ESTADO_DATOS2);
			}
		}
		public function datosCancelarClick(e:Event=null) {
				this.gotoEstado(this.ESTADO_ESCENA);
		}
		
		public function datosEntrar2() {
			tDireccion.text=datosDireccion;
			bContinuar.addEventListener(MouseEvent.CLICK, datosContinuarClick);
		}
		public function datosSalir2() {};
		
		public function datosContinuarClick(e:Event=null) {
			// GUARDAR FOTO
			trace("GUARDAR FOTO");
			if (lastFoto!=null) {
				//save bitmap image
				var jpg:JPGEncoder = new JPGEncoder(100);
				var byteArray:ByteArray = jpg.encode(lastFoto);
				
				var fileFolder:File=(new File(File.applicationDirectory.nativePath)).resolvePath("photo");
				//var filename:String=Base64.encode(datosDireccion);
				var filename:String=datosDireccion;
				var myFile:File=fileFolder.resolvePath(filename+".jpg");
				
				var fs:FileStream = new FileStream();
				fs.open(myFile, FileMode.WRITE);
				fs.writeBytes(byteArray, 0, byteArray.length);
				fs.close();
				
				// agregar mail (nombre foto: "filename" a la lista)
				myFile=fileFolder.resolvePath("mails.txt");
				fs.open(myFile, FileMode.APPEND);
				fs.writeUTFBytes(filename);
				fs.writeUTFBytes("\r\n");
				fs.close();
			}
			
			this.gotoEstado(this.ESTADO_ESCENA);
		};
		
		// ---------------------------------------------------------------------------------- FIN
		public function finEntrar() {}
		public function finSalir() {}
		
		// ------------------------------------------------------------------------------- CALIBRAR
		public function calibrarSwap() {
			this.calibrando=!this.calibrando
			if (this.calibrando) {
				// entrar calibrar
				this.debug.visible=true;
				alert_calibrando.visible=true;
				cajasContainer.visible=true;
			} else {
				// salir calibrar
				this.debug.visible=false;
				alert_calibrando.visible=false;
				cajasContainer.visible=false;
				hideGeom=false;
			}
		}
		public function cromaCargar() {
			if (so!=null) {
				if (so.data.cromaR!=undefined) rr=Number(so.data.cromaR);
				if (so.data.cromaG!=undefined) rg=Number(so.data.cromaG);
				if (so.data.cromaB!=undefined) rb=Number(so.data.cromaB);
				if (so.data.cromaUmbral!=undefined) umbral=Number(so.data.cromaUmbral);
			}
		}
		public function cromaGuardar() {
			if (so!=null) {
				so.data.cromaR=rr;
				so.data.cromaG=rg;
				so.data.cromaB=rb;
				so.data.cromaUmbral=umbral;
				so.flush();
			}
		}
		public function mascaraCargar() {
			if (so!=null) {
				if (so.data.mascaraScale!=undefined) mascaraScale=Number(so.data.mascaraScale);
				if (so.data.mascaraX!=undefined) mascaraOffsetX=Number(so.data.mascaraX);
				if (so.data.mascaraY!=undefined) mascaraOffsetY=Number(so.data.mascaraY);
				maskMat=new Matrix();
				maskMat.translate(mascaraOffsetX, mascaraOffsetY);
				maskMat.scale(mascaraScale,mascaraScale);
			}
		}
		public function mascaraGuardar() {
			if (so!=null) {
				so.data.mascaraScale=mascaraScale;
				so.data.mascaraX=mascaraOffsetX;
				so.data.mascaraY=mascaraOffsetY;
				so.flush();
				maskMat=new Matrix();
				maskMat.translate(mascaraOffsetX, mascaraOffsetY);
				maskMat.scale(mascaraScale,mascaraScale);
			}
		}
		public function cargarBlur() {
			blur  = new BlurFilter();
			blur.blurX = blur.blurY = 8; 
			if (so!=null) {
				if (so.data.blurX!=undefined) blur.blurX=Number(so.data.blurX);
				if (so.data.blurY!=undefined) blur.blurY=Number(so.data.blurY);
			}
			blur.quality = BitmapFilterQuality.MEDIUM;
		}
		public function guardarBlur() {
			if (so!=null) {
				so.data.blurX=blur.blurX;
				so.data.blurY=blur.blurY;
				so.flush();
			}
		}
		public function vistaCargar() {
			if (so!=null) {
				if (!isNaN(so.data.vistaR)) _view.camera.rotationZ=so.data.vistaR;
				if (!isNaN(so.data.vistaX)) _view.camera.x=so.data.vistaX;
				if (!isNaN(so.data.vistaY)) _view.camera.y=so.data.vistaY;
				if (!isNaN(so.data.vistaZ)) _view.camera.z=so.data.vistaZ;
				if (!isNaN(so.data.vistaFov)) (_view.camera.lens as PerspectiveLens).fieldOfView=so.data.vistaFov;
			}
		}
		public function vistaGuardar() {
			if (so!=null) {
				so.data.vistaR=_view.camera.rotationZ;
				so.data.vistaX=_view.camera.x;
				so.data.vistaY=_view.camera.y;
				so.data.vistaZ=_view.camera.z;
				so.data.vistaFov=(_view.camera.lens as PerspectiveLens).fieldOfView;
				so.flush();
			}
		}
		public function geomCargar() {
			if (so!=null) {
				if (!isNaN(so.data.geomScaleX)) geomScaleX=so.data.geomScaleX;
				if (!isNaN(so.data.geomScaleY)) geomScaleY=so.data.geomScaleY;
				if (!isNaN(so.data.geomScaleZ)) geomScaleZ=so.data.geomScaleZ;
			}
		}
		public function geomGuardar() {
			if (so!=null) {
				so.data.geomScaleX=geomScaleX;
				so.data.geomScaleY=geomScaleY;
				so.data.geomScaleZ=geomScaleZ;
				so.flush();
			}
		}
		
		// ---------------------------------------------------------------------------------- TOOLS
		private function trans(ix:Number=0,iy:Number=0):Point {
			ix=(ix/1280)*bmdOrig.height;
			iy=1-(iy/720); // alto de 0..1 en pantalla (flip vertical)
			
			var sy:Number=1280/bmdOrig.height;	// escala para alto de cam 1280
			var tx:Number=bmdOrig.width*sy;	// aplicando misma escala, el ancho de cam
			// tenemos camara a, tx x 1280
			// si de 1280 veo 720... de tx veré ty
			//    1280/720 = tx/ty
			//    ty=tx*720/1280
			var ty:Number=tx*720/1280;		// cuanto veo (franja) en pantalla
			ty=ty/sy;		// deshaciendo escala (cuanto veo de cam)			
			iy=iy*ty+(bmdOrig.width-ty)*0.5; // aplicar coordenada, mas la mitad de lo que pierdo
			
			var t:Point=new Point(iy,ix); // voltear x,y (rotacion de 90 grados)
			return t;
		}
		private function invtrans(ix:Number=0,iy:Number=0):Point {	
			// voltear x,y (rotacion de 90 grados)
			var temp:Number=ix;
			ix=iy;
			iy=temp;
			
			if (bmdOrig!=null) {
				var sy:Number=1280/bmdOrig.height;	// escala para alto de cam 1280
				var tx:Number=bmdOrig.width*sy;	// aplicando misma escala, el ancho de cam
				var ty:Number=tx*720/1280;		// cuanto veo (franja) en pantalla
				ty=ty/sy;		// deshaciendo escala (cuanto veo de cam)		
				iy=(iy-(bmdOrig.width-ty)*0.5)/ty;
				iy=(1-iy)*720;
				ix=1280*ix/bmdOrig.height;
			}
			
			var t:Point=new Point(ix,iy); 
			return t;
		}
		private function ajustarUmbral(e:MouseEvent) {
			if (!calibrando) return;
			umbral+=e.delta;
			if (umbral<0) umbral=0;
			if (umbral>255) umbral=255;
			cromaGuardar();
		}
		private var minh:Number,mins:Number,minv:Number,maxh:Number,maxs:Number,maxv:Number;
		private var cogiendoColor:Boolean=false;
		private function cogerColorIni(e:MouseEvent) {
			if (!calibrando) return;
			cogiendoColor=true;
			if (!e.ctrlKey) { // si no ctrl... iniciar rango (si no... solo sumar para click
				var p:Point=trans(e.stageX,e.stageY);
				var c:uint=bmdOrig.getPixel(p.x,p.y);
				//var ia=(pval>>24)&0xFF; // shift Argb
				var tr:uint=(c>>16)&0xFF; // shift aRgb
				var tg:uint=(c>>8)&0xFF; // shift arGb
				var tb:uint=(c)&0xFF; // noshift nedded argB
				rgb2hsvReturn=rgb2hsv(tr,tg,tb);
				minh=rgb2hsvReturn.r;
				mins=rgb2hsvReturn.g;
				minv=rgb2hsvReturn.b;
				umbral=0;
				cromaGuardar();
				/*
				minh=maxh=Number(rgb2hsvReturn.r);
				mins=maxs=Number(rgb2hsvReturn.g);
				minv=maxv=Number(rgb2hsvReturn.b);
				//*/
			} else cogerColorFin(e);
			
			ftrace();
			ftrace("h:"+minh+"/"+maxh);
			ftrace("s:"+mins+"/"+maxs);
			ftrace("v:"+minv+"/"+maxv);
			ftrace("r:"+tr+" g:"+tg+" b:"+tb+"  u:"+umbral);
			ftrace("r:"+rgb2hsvReturn.r+" g:"+rgb2hsvReturn.g+" b:"+rgb2hsvReturn.b);
			ftrace("down");
		}
		private function cogerColorMove(e:MouseEvent) {
			if (!calibrando) return;
			if (cogiendoColor) {
				var p:Point=trans(e.stageX,e.stageY);
				var c:uint=bmdOrig.getPixel(p.x,p.y);
				//var ia=(pval>>24)&0xFF; // shift Argb
				var tr:uint=(c>>16)&0xFF; // shift aRgb
				var tg:uint=(c>>8)&0xFF; // shift arGb
				var tb:uint=(c)&0xFF; // noshift nedded argB
				rgb2hsvReturn=rgb2hsv(tr,tg,tb);
				
				// nueva media
				maxh=(minh+rgb2hsvReturn.r)*0.5;
				maxs=(mins+rgb2hsvReturn.g)*0.5;
				maxv=(minv+rgb2hsvReturn.b)*0.5;
				var dif:Number=(Math.abs(maxh-minh)+Math.abs(maxs-mins)+Math.abs(maxv-minv));
				if (dif>umbral) umbral=dif;
				rr=minh=maxh;
				rg=mins=maxs;
				rb=minv=maxv;
				cromaGuardar();
				
				/*
				if (rgb2hsvReturn.r>maxh) maxh=rgb2hsvReturn.r;
				if (rgb2hsvReturn.r<minh) minh=rgb2hsvReturn.r;
				if (rgb2hsvReturn.g>maxs) maxs=rgb2hsvReturn.g;
				if (rgb2hsvReturn.g<mins) mins=rgb2hsvReturn.g;
				if (rgb2hsvReturn.b>maxv) maxv=rgb2hsvReturn.b;
				if (rgb2hsvReturn.b<minv) minv=rgb2hsvReturn.b;
				//*/
				ftrace();
				ftrace("h:"+minh+"/"+maxh);
				ftrace("s:"+mins+"/"+maxs);
				ftrace("v:"+minv+"/"+maxv);
				ftrace("r:"+tr+" g:"+tg+" b:"+tb+"  u:"+umbral);
				ftrace("r:"+rgb2hsvReturn.r+" g:"+rgb2hsvReturn.g+" b:"+rgb2hsvReturn.b);
			}
		}
		private function cogerColorFin(e:MouseEvent) {
			if (!calibrando) return;
			if (cogiendoColor) {
				var p:Point=trans(e.stageX,e.stageY);
				var c:uint=bmdOrig.getPixel(p.x,p.y);
				//var ia=(pval>>24)&0xFF; // shift Argb
				var tr:uint=(c>>16)&0xFF; // shift aRgb
				var tg:uint=(c>>8)&0xFF; // shift arGb
				var tb:uint=(c)&0xFF; // noshift nedded argB
				rgb2hsvReturn=rgb2hsv(tr,tg,tb);
				
				// nueva media
				maxh=(minh+rgb2hsvReturn.r)*0.5;
				maxs=(mins+rgb2hsvReturn.g)*0.5;
				maxv=(minv+rgb2hsvReturn.b)*0.5;
				var dif:Number=(Math.abs(maxh-minh)+Math.abs(maxs-mins)+Math.abs(maxv-minv))/3;
				if (dif>umbral) umbral=dif;
				rr=minh=maxh;
				rg=mins=maxs;
				rb=minv=maxv;
				cromaGuardar();
				
				/*
				if (rgb2hsvReturn.r>maxh) maxh=rgb2hsvReturn.r;
				if (rgb2hsvReturn.r<minh) minh=rgb2hsvReturn.r;
				if (rgb2hsvReturn.g>maxs) maxs=rgb2hsvReturn.g;
				if (rgb2hsvReturn.g<mins) mins=rgb2hsvReturn.g;
				if (rgb2hsvReturn.b>maxv) maxv=rgb2hsvReturn.b;
				if (rgb2hsvReturn.b<minv) minv=rgb2hsvReturn.b;
				
				// calcular media y desviacion tipica (umbral)
				rr=(maxh+minh)*0.5;
				rg=(maxs+mins)*0.5;
				rb=(maxv+minv)*0.5;
				umbral=(Math.abs(maxh-minh)+Math.abs(maxs-mins)+Math.abs(maxv-minv))*0.5/3;
				//*/
				
				ftrace();
				ftrace("h:"+minh+"/"+maxh);
				ftrace("s:"+mins+"/"+maxs);
				ftrace("v:"+minv+"/"+maxv);
				ftrace("r:"+tr+" g:"+tg+" b:"+tb+"  u:"+umbral);
				ftrace("r:"+rgb2hsvReturn.r+" g:"+rgb2hsvReturn.g+" b:"+rgb2hsvReturn.b);
				ftrace("r:"+rr+" g:"+rg+" b:"+rb+"  u:"+umbral);
			}
			cogiendoColor=false;
		}
		
		var R:Number,G:Number,B:Number;
		var H:Number=0,S:Number,V:Number;
		var Mx:Number;
		var Mn:Number;
		var rgb2hsvReturn:Object=new Object();
		private function rgb2hsv(RH:uint,GS:uint,BV:uint):Object {
			H=0;
			R=RH/255.0; G=GS/255.0; B=BV/255.0;
		 	Mx=Math.max(Math.max(R,G),B);
			Mn=Math.min(Math.min(R,G),B);
			V=Mx;
			if (Mx==0) S=0; else S=1.0-(Mn/Mx);
			if (Mx==Mn) H=240/360; // sin Tono concreto... cualquiera //0 rojo, 120 verde, 240 azul
			else {  // calcular y comprobar el tono concreto
				if (Mx==B) H=(((R-G)*60)/(Mx-Mn))+240;
				if (Mx==G) H=(((B-R)*60)/(Mx-Mn))+120;
				if (Mx==R) H=(((G-B)*60)/(Mx-Mn));
				if (H<0) H+=360;
						// H=0...360 -> escalar a 0...256
				// de 0..360 -> 0..1
				H=H/360.0; //*0.7083; //*(255/360)
			} // sinTono
		
			// HSV de 0 a 1
			RH=(H*255);
			GS=(S*255);
			BV=(V*255);
			rgb2hsvReturn.r=RH;
			rgb2hsvReturn.g=GS;
			rgb2hsvReturn.b=BV;
			return rgb2hsvReturn;
		}
		
		private function ftrace(t="") {
		}
		private function fftrace(t="") {
			if (t!="") 
			debug.appendText(t+"\n");
			else debug.text="";
		}

		// -------------------------------------------------------------------------------------------
		
		// ---------------------------------------------------------------------------------- VIDEOS
		// ================================================= METADATAS ===============================
		public function onXMPData(infoObject:Object):void {}
		public function asyncErrorHandler(event:AsyncErrorEvent):void {
			trace("asyncErrorHandler: "+event.text);  // this will handle any errors with video playback  
		}
		public function onMetaData(newMeta:Object):void {  
			//trace("Metadata: duration=" + newMeta.duration + " width=" + newMeta.width + " height=" + newMeta.height + " framerate=" + newMeta.framerate);  // traces what it says  
			//duration = newMeta.duration;  // set the duration variable to the newMeta's duration 
			//if (this.activeVideo1) {
			//	TweenNano.to(holder2,currentEstado.fadeTime,{delay:0.2,alpha:0,onUpdate:fadeAudio});
			//} else {
			//	TweenNano.to(holder2,currentEstado.fadeTime,{delay:0.2,alpha:1,onUpdate:fadeAudio});
			//}
		}
		public function onPlayStatus(status:Object):void {}
		function netStatus(event:NetStatusEvent):void  { 
			//trace(event.info.code);  // this will handle any events that are fired when the video is playing back  
			switch(event.info.code)  //  switch statement to handle the various events with the NetConnection  
			{  
				case "NetStream.Play.StreamNotFound": //error if stream file not found in location specified
					trace("  ERR: Stream not found...");
				break;
				/*/
				case "NetStream.Buffer.Full":  //  when our buffer is full fire the code below  
					if (this.activeVideo1) {
						TweenNano.to(holder2,currentEstado.fadeTime,{delay:0,alpha:0,onUpdate:fadeAudio});
					} else {
						TweenNano.to(holder2,currentEstado.fadeTime,{delay:0,alpha:1,onUpdate:fadeAudio});
					}
				break;  
				/*
				case "NetStream.Buffer.Empty":  //  when our buffer is empty fire the code below  
					ns.bufferTime = 10;  // set buffer time to 10 seconds  
					Tweener.addTween(videoPreloader, {alpha:1, time:.3});  // tween videoPreloaders alpha to 1  
				break;  
				/*
				case "NetStream.Play.Start":  //  when our video starts playing we fire the code below  
					if (this.activeVideo1) {
						TweenNano.to(holder2,currentEstado.fadeTime,{delay:0,alpha:0,onUpdate:fadeAudio});
					} else {
						TweenNano.to(holder2,currentEstado.fadeTime,{delay:0,alpha:1,onUpdate:fadeAudio});
					}
				break; 
				/*
				case "NetStream.Seek.Notify":  // when you seek with the scrubber it sends a notify signal of the time  
					ns.bufferTime = 10;  // set the buffer time to 10 seconds  
					Tweener.addTween(videoPreloader, {alpha:1, time:.3});  //  tween videoPreloaders alpha to 1  
				break;  
				case "NetStream.Seek.InvalidTime":  // when you release the scrubber ahead of the video that has been loaded, you get this error.  it will jump you back to the last frame that has been loaded  
					ns.bufferTime = 10;  // set the buffer time to 10 seconds  
					Tweener.addTween(videoPreloader, {alpha:1, time:.3});  //  tween videoPreloaders alpha to 1  
				break;  
				case "NetStream.Buffer.Flush":
					if (tns==ns1) this.flushed1=true;
					if (tns==ns2) this.flushed2=true;
				break;
				//*/
				case "NetStream.Buffer.Empty": // antes del stop (para tratar de evitar frame negro)
				case "NetStream.Play.Stop":  // when you reach the end of the video  
					// rewind and loop
					ns.pause();  // pause the video
					ns.seek(0);  // seek the video to the first frame
					ns.resume();
				break;  
			}  
		} 
		// ================================================= METADATAS ===============================

		
	}
	
}
