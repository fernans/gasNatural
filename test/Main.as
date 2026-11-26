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
	
	
	
	public class Main extends MovieClip {
		
		// ------------------
		// min-fer = 4    (160x120)
		// normal  = 1    (640x480)
		// super   = 0.5 (1280x960)
		public const fer_escalar:Number=4;		// 1=640x480=ok 0.8=800x600=no 0.625=1024x768=no 0.5=1280x960=ok
		public const fer_croma:Boolean=true;	// true
		public const fer_grafica:Boolean=true;	// true
		public const fer_video:Boolean=false;	// true
		public const fer_3d:Boolean=true;		// false
		public const fer_over:Boolean=false;	// false
		// ------------------
		
		// estados
		public const ESTADO_PREINIT=1; 	// antes de iniciar
		public const ESTADO_INIT=2;		// iniciando kinect
		public const ESTADO_ESCENA=3;	// en escena (tanto si hay jugador o no)
		public const ESTADO_FOTO=4; 	// cuenta atrás y sacar foto
		public const ESTADO_DATOS=5;	// introducir mail (teclado normal)
		public const ESTADO_FIN=6;	  	// gracias, y vuelta a escena
		private var estado:Number=ESTADO_PREINIT;
		
		// kinect
		private var device:Kinect=null;
		private var camara:Bitmap;		// <-- solo para mostrar en 2D
		private var bmdOrig:BitmapData;	// pre-croma
		private var bmd:BitmapData;		// con croma
		private var bmd2:BitmapData;	// escalado a potencia de 2 (1024x1024)
		private var bmd2m:Matrix;		// (transformacion a potencia de 2)
		private var bmd2t:BitmapTexture; // textura para away3D
		private var currentUser:User=null;
		
		// away3D
		private var _view:View3D;
		private var elementsLoaded:int=0;
		private var elementsToLoad:int=0;
		
		private var cajas:Vector.<Mesh>=new Vector.<Mesh>();
		
		private var rootPose:SkeletonPose;
		private var jointMapping:Dictionary=null;
		
		
		// chroma
		private var a:Vector.<uint>=new Vector.<uint>();
		
		// videos fondos
		private var nc:NetConnection;
		private var ns:NetStream;
		private var video:Video;
		[Embed(source="./media/fondo_cocina.jpg")]
		private var FondoCocina:Class;
		
		
		// over
		private var mano:Mano;
		private var manoPulsando:MovieClip=null;
		private var manoTimer:Timer=new Timer(2*1000);   // 2 segundos sobre
		
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
				case ESTADO_FIN:
					// nada... (volver a escena libremente)
				break;
				default: break;
			}
			return true; // por defecto, se permite el cambio de estado
		}
		
		// ---------------------------------------------------------------------------------- EXIT
		public function end(e:Event=null) {
			NativeApplication.nativeApplication.removeEventListener(Event.EXITING, end);
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
		}
		
		private var modo:Number=1;
		private var msx:Number=1;
		private var msy:Number=0.1;
		private var msz:Number=0.1;
		// ---------------------------------------------------------------------------------- TECLA
		public function tecla(e:KeyboardEvent=null) {			
			if (e.keyCode==Keyboard.BACKSPACE) gotoEstado(this.ESTADO_ESCENA); // reset			
			if (e.keyCode==Keyboard.ESCAPE) NativeApplication.nativeApplication.activeWindow.close();
			if (e.keyCode==Keyboard.NUMBER_1) modo=1;
			if (e.keyCode==Keyboard.NUMBER_2) modo=2;
			if (e.keyCode==Keyboard.NUMBER_3) modo=3;
			if (e.keyCode==Keyboard.NUMBER_4) modo=4;
			if (e.keyCode==Keyboard.NUMBER_5) modo=5;
			if (e.keyCode==Keyboard.NUMBER_6) modo=6;
			if (e.keyCode==Keyboard.X) {msx=1;msy=0.2;msz=0.2;}
			if (e.keyCode==Keyboard.Y) {msx=0.2;msy=1;msz=0.2;}
			if (e.keyCode==Keyboard.Z) {msx=0.2;msy=0.2;msz=1;}
		}
		
		// ---------------------------------------------------------------------------------- INIT
		public function initEntrar() {
			// poner pantalla completa ---------------------------------------------
			if (!Capabilities.isDebugger)
			{
				stage.displayState=StageDisplayState.FULL_SCREEN_INTERACTIVE;
				stage.scaleMode=StageScaleMode.SHOW_ALL;
				//Mouse.hide();
			}
			//stage.align=""; // center v, center h
			stage.align=StageAlign.TOP_LEFT;
			NativeApplication.nativeApplication.addEventListener(Event.EXITING, end);
			stage.addEventListener(KeyboardEvent.KEY_DOWN, tecla);
			
			
			// iniciar kinect ------------------------------------------------------
			alert_ErrorKinect.visible=false;
			if (Kinect.isSupported()) {
				trace("Iniciando Kinect...");
				device=Kinect.getDevice();
				var settings:KinectSettings=new KinectSettings();
				settings.rgbEnabled=true;
				settings.rgbResolution=new Point(640/fer_escalar,480/fer_escalar);
			
				device.addEventListener(CameraImageEvent.RGB_IMAGE_UPDATE, camRgbUpdate);
				
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
			_view.camera.z = -1000;
			_view.camera.lookAt(new Vector3D(0,0,0));
			_view.camera.y = 500;
			stage.addEventListener(Event.RESIZE, away_onResize);
			away_onResize();
			addEventListener(Event.ENTER_FRAME, away_onEnterFrame);
			
			// kinect camera ?¿
			//_view.camera.z = 13 * -14;
        	//_view.camera.y = 170 * .5;

			if (this.fer_3d) {
				// cajas
				var rojoMat:ColorMaterial=new ColorMaterial(0xFF0000);
				var verdeMat:ColorMaterial=new ColorMaterial(0x00FF00);
				var azulMat:ColorMaterial=new ColorMaterial(0x00AAFF);
				for (var i:int=0;i<20;i++) {
					// 20 huesos-cajas
					var ob:Mesh=new Mesh(new CubeGeometry(1,1,1));
					
					var r:Mesh=new Mesh(new CubeGeometry(200,10,10), rojoMat );
					r.x=100;
					ob.addChild(r);
					var g:Mesh=new Mesh(new CubeGeometry(10,200,10), verdeMat );
					g.y=100;
					ob.addChild(g);
					var b:Mesh=new Mesh(new CubeGeometry(10, 10,200), azulMat );
					b.z=100;
					ob.addChild(b);
					
					cajas.push(ob);
					_view.scene.addChild(ob);
				}
				
				//*
				// load models			
				AssetLibrary.enableParser(AWD2Parser);
				AssetLibrary.enableParser(MD5MeshParser);
				AssetLibrary.addEventListener(AssetEvent.ASSET_COMPLETE, onAssetComplete);
				AssetLibrary.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);
				AssetLibrary.addEventListener(LoaderEvent.LOAD_ERROR, onLoadError);
				elementsToLoad=1;
				AssetLibrary.load(new URLRequest("media/a.awd")); 
				//*/
			}
			trace("Away3D iniciado");
			
			
			// --- iniciar Videos fondo ---------------------------------------------------
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
			if (this.fer_video) {
				ns.play("media/video1.mov");
			}
			trace("Viedos fondo Iniciado");
			
			// cursor-mano -----------------------------------------------
			if (this.fer_over) {
				mano=new Mano();
				mano.visible=false;
				addChild(mano);
				manoTimer.addEventListener(TimerEvent.TIMER,manoTimerComplete);
			} else {
				botonFoto.visible=false;
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
			// To not see these names output in the console, comment the
			// line below with two slash'es, just as you see on this line
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
			trace("setupScene");
			
			// elementos a buscar
			var hero:Mesh;
			var modelTexture:BitmapTexture;
			var skeleton:Skeleton;
			
			skeleton = Skeleton(AssetLibrary.getAsset("skeleton"));
			hero = Mesh(AssetLibrary.getAsset("mesh"));
			
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
			
			// debo tenerlo todo
			if (skeleton==null) {trace("NO SKELETON");return;}
			if (hero==null) {trace("NO MESH");return;}
			
			trace("lo tengo todo");
			
			//modelTexture = BitmapTexture(AssetLibrary.getAsset("media/onkba_N.jpg"));
			//var material:TextureMaterial = new TextureMaterial(modelTexture);
			//material.normalMap = new BitmapTexture(autoMap.bitdata[1]);
			//material.specularMap = new BitmapTexture(autoMap.bitdata[2]);
			//material.specularMethod = specularMethod;
			//material.lightPicker = lightPicker;
			//material.gloss = 40;
			//material.specular = 0.5;
			//material.ambientColor = 0xAAAAFF;
			//material.ambient = 0.25;
			//material.addMethod(new RimLightMethod(DemoColor[1], .4, 3, RimLightMethod.ADD));
			
			// put our hero center stage and assign our material object
			//hero.material = material;
			hero.scale(8);
			hero.castsShadows = true;
			hero.z = 0;
			//hero.rotationY = -45;
			
			
			_view.scene.addChild(hero);
			
			// create a null-pose from the current skeleton position
			rootPose = new SkeletonPose();
			for each(var joint:away3d.animators.data.SkeletonJoint in skeleton.joints){
				//joint.inverseBindPose = Vector.<Number>([1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]);
				var bind:Matrix3D = new Matrix3D(joint.inverseBindPose);
				bind.invert();
				var jp:JointPose=new JointPose();
				jp.name=joint.name;
				//jp.orientation.fromMatrix(bind);
				//jp.translation=bind.position;
				trace("_____________");
				trace(jp.name);
				trace(joint.inverseBindPose.toString());
				//trace(com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_UPPER_ARM);
				if (jp.name==com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.SPINE) {
					trace(">>> modificando down");
					jp.orientation.fromAxisAngle(new Vector3D(0,0,1),0.5*Math.PI*0.25);	  
				}
				if (jp.name==com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.RIGHT_LOWER_ARM) {
					trace(">>> modificando up");
					jp.orientation.fromAxisAngle(new Vector3D(0,0,1),-0.5*Math.PI*0.25);	  
				}
				//jp.translation=new Vector3D(0,0,0);
				rootPose.jointPoses.push(jp); // need so many null-jointPoses as skeleton joints has
				//rootPose.jointPoses.push(new JointPose()); // need so many null-jointPoses as skeleton joints has
				//trace("  bones: "+joint.name);
				//joint.inverseBindPose = Vector.<Number>([1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]);
			}
			
			// create an idle animation clip by adding the root null-pose twice
			var clip:SkeletonClipNode = new SkeletonClipNode();
			clip.addFrame(rootPose, 1000); clip.addFrame(rootPose, 1000);
			clip.name = "idle";
			// build animation set (with just the clip of null-poses)
			var animSet:SkeletonAnimationSet = new SkeletonAnimationSet(5); // joins-per-vertex
			animSet.addAnimation(clip);
			// setup animator with animation set and skeleton
			var animator:SkeletonAnimator = new SkeletonAnimator(animSet, skeleton);
			hero.animator = animator;
			animator.play("idle");
			
			//*/
			
			// generate dictionary of index from this skeleton
			createMappingForKinectJointsToMeshBones(skeleton);
			
		}
		private function createMappingForKinectJointsToMeshBones(_skeleton:Skeleton) {
			jointMapping = new Dictionary();
	
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.HEAD] = _skeleton.jointIndexFromName("neck");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.NECK] = _skeleton.jointIndexFromName("neck");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.TORSO] = _skeleton.jointIndexFromName("spine");
	
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.LEFT_SHOULDER] = _skeleton.jointIndexFromName("right_upper_arm");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.LEFT_ELBOW] = _skeleton.jointIndexFromName("right_lower_arm");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.LEFT_HAND] = _skeleton.jointIndexFromName("right_hand");
	
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.RIGHT_SHOULDER] = _skeleton.jointIndexFromName("left_upper_arm");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.RIGHT_ELBOW] = _skeleton.jointIndexFromName("left_lower_arm");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.RIGHT_HAND] = _skeleton.jointIndexFromName("left_hand");
	
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.LEFT_HIP] = _skeleton.jointIndexFromName("right_upper_leg");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.LEFT_KNEE] = _skeleton.jointIndexFromName("right_lower_leg");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.LEFT_FOOT] = _skeleton.jointIndexFromName("right_foot");
	
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.RIGHT_HIP] = _skeleton.jointIndexFromName("left_upper_leg");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.RIGHT_KNEE] = _skeleton.jointIndexFromName("left_lower_leg");
			jointMapping[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.RIGHT_FOOT] = _skeleton.jointIndexFromName("left_foot");
		}
		
		
		// ---------------------------------------------------------------------------------- ESCENA
		public function escenaEntrar() {}
		public function escenaSalir() {}
		
		private function away_onEnterFrame(e:Event):void
		{
			//trace("App frame draw");
			if (this.fer_croma) {
				processCroma();
			}
			if (this.fer_3d) {
				if (currentUser!=null) {
					updateSkeleton(rootPose, currentUser);
				}
			}
			if (this.fer_over) {
				updateMano();
			}
			if (this.fer_grafica || this.fer_3d) {
				_view.render();
			}
		}
		
		public function playerEnters(event:UserEvent=null) {
			if (currentUser==null) {
				trace("User Enters", event.users);
				currentUser=event.users[0];
			}
			//sj.position.world
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
			if (currentUser!=null) {
				var antes:Boolean=mano.visible;
				
				var umbral:Number=Math.abs(currentUser.rightShoulder.position.world.x-currentUser.leftShoulder.position.world.x)*1.5;
				var actual:Number=currentUser.torso.position.world.z-currentUser.rightHand.position.world.z;
				mano.visible=(actual>umbral);
				if (mano.visible) {
					var p:Point=currentUser.rightHand.position.rgb;
					p.x=bmd.width*p.x/320;
					p.y=bmd.height*p.y/240;
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
						}
					} else {
						// test salir de zona
						if (!mano.hitTestObject(manoPulsando)) {
							manoPulsando=null;
							manoTimer.stop();
						}
					}
					
				} else {
					if (antes) {
						// desaparece, anula pulsaciones
						manoPulsando=null;
						manoTimer.stop();
					}
				}
			} else {
				// sin jugador no hay mano
				manoPulsando=null;
				manoTimer.stop();
				mano.visible=false;
			}
		}
		private function manoTimerComplete(e:Event=null) {
			trace("PULSADO: "+manoPulsando);
			manoTimer.stop();
		}
		
		// ------------------------------------------------------ update skeleton (3d)
		private function updateSkeleton(skel:SkeletonPose, u:User) {
			var jp:JointPose=skel.jointPoses[0];
			trace("JoinPose:  "+jp.name);
			trace("SkelJoint: "+com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.LEFT_HIP);
			trace("SkelBone:  "+com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_UPPER_LEG);
			var j:com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint=u.skeletonJoints[u.skeletonJointNameIndices[com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint.LEFT_HIP]]
			var b:com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone=u.skeletonBones[u.skeletonBoneNameIndices[com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone.LEFT_UPPER_LEG]];
			//jp.orientation.fromMatrix(b.orientation.absoluteOrientationMatrix);
			jp.translation=j.position.world;
			
			var box:Entity=cajas[0];
			//box.transform=jp.orientation.toMatrix3D();
			box.position=jp.translation;
		}
		private function updateSkeletonB(skel:SkeletonPose, u:User) {
			var boxitem:int=0;
			for each (var b:SkeletonBone in u.skeletonBones) {
				var boneSelected:String="neck";
				//if (b.name.toLocaleLowerCase()!=boneSelected) continue;
				if (b.startJointName!=null && jointMapping[b.startJointName]!=undefined) {
					
					
					
					trace("=== box: "+boxitem);
					trace("("+b.name+") "+b.startJointName+"=>"+b.endJointName);
					var j:com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint=u.skeletonJoints[u.skeletonJointNameIndices[b.startJointName]];
					var box:Entity=cajas[boxitem++];
					var jp:JointPose=rootPose.jointPoses[jointMapping[b.startJointName]];
					jp.orientation.fromMatrix(b.orientation.absoluteOrientationMatrix);
					jp.translation=j.position.world;
					
					/*
					//box.transform=b.orientation.absoluteOrientationMatrix;
					var rotTemp:Matrix3D=b.orientation.absoluteOrientationMatrix;
					var dec:Vector.<Vector3D>=rotTemp.decompose();  // 0=pos, 1=rot, 2=scale
					if (b.name.toLocaleLowerCase()=="right_upper_arm") {
						fftrace("");
						fftrace("rx="+dec[1].x);
						fftrace("ry="+dec[1].y);
						fftrace("rz="+dec[1].z);
						fftrace("mode="+modo);
					}
					//*/
					
					var rot:Matrix3D=b.orientation.absoluteOrientationMatrix;
					var q:Quaternion=new Quaternion();
					q.fromMatrix(b.orientation.absoluteOrientationMatrix);
					
					//var world:Matrix3D=new Matrix3D();world.identity();
					var world:Matrix3D=new Matrix3D(new Vector.<Number>([1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]));
					world.append(rot);
					//world.appendRotation(-q.w*360,new Vector3D(q.x,q.y,q.z));
					world.appendTranslation(j.position.world.x, j.position.world.y, j.position.world.z);
					//world=q.toMatrix3D();
					
					var qf:Quaternion=new Quaternion();
					qf.fromMatrix(world);
					
					box.transform=world;
					//box.position=j.position.world;
					
					// Sk.Inicial*Rotacion=Kin.Final
					// Rotacion=(^Sk.Inicial)*Kin.Final
					
					
					// SkInicial=Kinect*Rotacion
					// Rotacion=^Kinect*SkInicial
					// Sk.Final=Kinect*Rotacion
					
					// Ident=Kinect*Rotacion
					// Rotacion=^Kinect*Ident
					// SkFinal=Kinect*^Kinect*Ident
					
					//b.orientation.absoluteOrientationMatrix // Matriz [xx,xy,xz][yx,yy,yz][zx,zy,zz]
					if (b.name.toLocaleLowerCase()==boneSelected) {
						
						fftrace();
						fftrace("absoluteOrientationMatrix");
						fftrace(rot.rawData[0].toFixed(2)+", "+rot.rawData[1].toFixed(2)+", "+rot.rawData[2].toFixed(2)+", "+rot.rawData[3].toFixed(2));
						fftrace(rot.rawData[4].toFixed(2)+", "+rot.rawData[5].toFixed(2)+", "+rot.rawData[6].toFixed(2)+", "+rot.rawData[7].toFixed(2));
						fftrace(rot.rawData[8].toFixed(2)+", "+rot.rawData[9].toFixed(2)+", "+rot.rawData[10].toFixed(2)+", "+rot.rawData[11].toFixed(2));
						fftrace(rot.rawData[12].toFixed(2)+", "+rot.rawData[13].toFixed(2)+", "+rot.rawData[14].toFixed(2)+", "+rot.rawData[15].toFixed(2));
						fftrace("quaternion");
						fftrace(q.x.toFixed(2)+", "+q.y.toFixed(2)+", "+q.z.toFixed(2)+", "+q.w.toFixed(2)+" : "+q.magnitude.toFixed(2)+" ("+(q.w*360)+")");
						fftrace("world");
						fftrace(world.rawData[0].toFixed(2)+", "+world.rawData[1].toFixed(2)+", "+world.rawData[2].toFixed(2)+", "+world.rawData[3].toFixed(2));
						fftrace(world.rawData[4].toFixed(2)+", "+world.rawData[5].toFixed(2)+", "+world.rawData[6].toFixed(2)+", "+world.rawData[7].toFixed(2));
						fftrace(world.rawData[8].toFixed(2)+", "+world.rawData[9].toFixed(2)+", "+world.rawData[10].toFixed(2)+", "+world.rawData[11].toFixed(2));
						fftrace(world.rawData[12].toFixed(2)+", "+world.rawData[13].toFixed(2)+", "+world.rawData[14].toFixed(2)+", "+world.rawData[15].toFixed(2));
						fftrace("quaternion final");
						fftrace(qf.x.toFixed(2)+", "+qf.y.toFixed(2)+", "+qf.z.toFixed(2)+", "+qf.w.toFixed(2)+" : "+qf.magnitude.toFixed(2));
					}
					
					
					
					/*
					dec[0]=j.position.world;
					//*
					switch(modo) {
						case 1:
							dec[1]=new Vector3D(dec[1].x,dec[1].y,dec[1].z);		//(x,z,y)    y de lado
						break;
						case 2:
							dec[1]=new Vector3D(dec[1].x,dec[1].z,dec[1].y);		//(x,z,y)    y de lado
						break;
						case 3:	
							dec[1]=new Vector3D(dec[1].y,dec[1].x,dec[1].z);		//(x,z,y)    y de lado
						break;
						case 4:	
							dec[1]=new Vector3D(dec[1].y,dec[1].z,dec[1].x);		//(x,z,y)    y de lado
						break;
						case 5:	
							dec[1]=new Vector3D(dec[1].z,dec[1].x,dec[1].y);		//(x,z,y)    y de lado
						break;
						case 6:
							dec[1]=new Vector3D(dec[1].z,dec[1].y,dec[1].x);		//(x,z,y)    y de lado
						break;
						default: break;
					}
					dec[1].x=0;
					dec[1].y=0;
					dec[2]=new Vector3D(msx,msy,msz);
					//rotTemp=new Matrix3D(dec);
					rotTemp.recompose(dec);

					box.transform=rotTemp;
					//box.position=j.position.world;
					//*/
					
					//box.eulers=rot;
					//box.position=j.position.world;
					//var orient:Vector3D=b.orientation.absoluteOrientationMatrix.decompose();
					//box.eulers=orient;
					//box.transform=Matrix3D;
					
					//var jp:JointPose=rootPose.jointPoses[jointMapping[j.name]];
					//jp.orientation.fromMatrix(b.orientation.absoluteOrientationMatrix);
					//jp.translation=j.position.world;
				}
			}
			trace("===================");
					/*
					var sj:com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint=u.head;
					for each (var b:SkeletonBone in u.skeletonBones) {
						if (u.skeletonJointNameIndices[b.startJointName]!=undefined) {
							var j:com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint=u.skeletonJoints[u.skeletonJointNameIndices[b.startJointName]];
							if (jointMapping[j.name]>-1) {
								var jp:JointPose=rootPose.jointPoses[jointMapping[j.name]];
								jp.orientation.fromMatrix(b.orientation.absoluteOrientationMatrix);
								jp.translation=j.position.world;
							}
						}
					}
					//*/
					/*
					for each(var jp:away3d.animators.data.JointPose in skel.jointPoses){
						
						//jp.translation=bind.position;
						//jp.translation=new Vector3D(0,50,0);
						jp.translation.x=sj.position.world.x/100;
						jp.translation.y=sj.position.world.y/100;
						jp.translation.z=sj.position.world.z/100;
						jp.orientation=new Quaternion();
					}
					//*/
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
		
		// ------------------------------------------------------------------------- CROMA
		private var rr:Number=0, rg:Number=0, rb:Number=0, umbral:Number=32; // color ref y umbral
		private var pval:uint, oval:uint;	// pixel entrada / pixel salida
		private var ia:Number, ir:Number, ig:Number, ib:Number;	// valores de entrada (Desglosado)
		private var cr:Number, cg:Number, cb:Number; 			// copias de entrada (para convertir a HSV)
		private var i:Number;	// bucle
		private var p:Vector.<uint>, plen:Number;	// pixels bytearray, y length
		private var dist:Number, temp:Number; 		// distancia (parcial) / acumulado
		public function processCroma() {
			//trace("Process Chroma");
			if (bmdOrig==null) return; // esperar a tener "al menos" el primer frame

			bmd=bmdOrig.clone();	// para referencia a la hora de pulsar-arrastrar (elegir color croma)
			
			if (camara!=null) camara.bitmapData=bmd; // update bitmap data
			
			// CROMA
			if (this.fer_croma) {
				// alpha por color
				p=bmd.getVector(bmd.rect);
				plen=p.length;
	
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
				}
				// actualizar bitmap con el croma
				bmd.setVector(bmd.rect,p);
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
				var fondoFijo:BitmapData=Cast.bitmapData(this.FondoCocina);
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
		
		// ---------------------------------------------------------------------------------- FOTO
		public function fotoEntrar() {}
		public function fotoSalir() {}
		
		// ---------------------------------------------------------------------------------- DATOS
		public function datosEntrar() {}
		public function datosSalir() {}
		
		// ---------------------------------------------------------------------------------- FIN
		public function finEntrar() {}
		public function finSalir() {}
		
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
			
			var sy:Number=1280/bmdOrig.height;	// escala para alto de cam 1280
			var tx:Number=bmdOrig.width*sy;	// aplicando misma escala, el ancho de cam
			var ty:Number=tx*720/1280;		// cuanto veo (franja) en pantalla
			ty=ty/sy;		// deshaciendo escala (cuanto veo de cam)		
			iy=(iy-(bmdOrig.width-ty)*0.5)/ty;
			iy=(1-iy)*720;
			ix=1280*ix/bmdOrig.height;
			
			var t:Point=new Point(ix,iy); 
			return t;
		}
		private function ajustarUmbral(e:MouseEvent) {
			umbral+=e.delta;
			if (umbral<0) umbral=0;
			if (umbral>255) umbral=255;
		}
		private var minh:Number,mins:Number,minv:Number,maxh:Number,maxs:Number,maxv:Number;
		private var cogiendoColor:Boolean=false;
		private function cogerColorIni(e:MouseEvent) {
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
