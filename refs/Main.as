package  {
	
	import flash.display.MovieClip;
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.ui.Keyboard;
	import flash.display.StageDisplayState;
	import flash.display.StageScaleMode;
	import flash.display.StageAlign;
	import flash.desktop.NativeApplication;
	import flash.media.SoundMixer;
	
	import com.greensock.TweenLite;
	import com.greensock.easing.*;
	
	import com.adobe.images.JPGEncoder;
	
	import flash.geom.Point;
	import flash.geom.Vector3D;
	import flash.display.Sprite;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.geom.Transform;
	import flash.geom.Rectangle;
	import flash.geom.Matrix;
	import flash.geom.ColorTransform;
	
	import com.as3nui.nativeExtensions.air.kinect.*;
	import com.as3nui.nativeExtensions.air.kinect.events.*;
	import com.as3nui.nativeExtensions.air.kinect.data.User;
	import com.as3nui.nativeExtensions.air.kinect.data.SkeletonJoint;
	import flash.media.Video;
	import flash.system.Capabilities;
	import flash.utils.Dictionary;
	import com.as3nui.nativeExtensions.air.kinect.data.SkeletonBone;
	import flash.geom.Matrix3D;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import flash.net.SharedObject;
	import flash.display.Loader;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.filesystem.FileMode;
	import flash.media.Sound;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.events.NetStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.globalization.DateTimeFormatter;
	import com.greensock.TweenMax;
	
	
	public class Main extends MovieClip {
		
		public static const KinectMaxDepthInFlash:uint = 200;
		public var explicitWidth:Number = 768; // 640
    	public var explicitHeight:Number = 576; // 480
		public var explicitScaleX:Number;
		public var explicitScaleY:Number;
		public var explicitStageWidth:Number;
		public var explicitStageHeight:Number;
		
		public const ESTADO_PREINIT=1; // antes de iniciar
		public const ESTADO_INIT=2; // iniciando kinect
		public const ESTADO_WAIT=3; // en espera (detectando entrada de jugador)
		public const ESTADO_DETECTEDINI=4; // detectado... presentacion de gesto
		public const ESTADO_DETECTED=5; // preparado, esperando gesto para empezar
		public const ESTADO_JUGANDO=6; // juego iniciado (por gesto  o por tecla)
		public const ESTADO_FIN=7;	// fin del juego (captura de foto)
		public const ESTADO_TOPTEN=8;	// listado de ganadores (score list)
		
		public const video_espera:String="video_espera.flv";
		public const video_preparados:String="video_preparados.flv";
		public const video_preparados_time:Number=7;
		public const video_jugando:String="video_jugando.flv";
		
		private var estado:Number=ESTADO_PREINIT;
		
		public var so:SharedObject;
		
		public var nc:NetConnection;
		public var ns:NetStream; // para video principal, inicio_jugo
		public var ns2:NetStream; // para video lateral
		
		public var espada:Espada=new Espada();
		public var espadaB:Espada=new Espada();
		public var areaEsferas:MovieClip=new MovieClip();
		
		private var device:Kinect=null;
		private var userHist:Array=new Array();
		private var currentUserId:Number=-1;
		//private var sombra:Bitmap;
		private var camara:Bitmap;
		private var oldcam:Array=new Array();
		private var oldframes:Number=3;
		
		private var nivel:Number=0;
		private var pendientes:Number=0;
		private var puntos:Number=0;
		public var gameId:Number=0;
		private const TIEMPO_JUEGO:Number=90;
		private var tiempo:Number=TIEMPO_JUEGO;
		private const MAX_SCORES:Number=NaN;
		
		private var timerJuego:Timer=null;
		private var miniFoto:Bitmap=null;
		private var fotoSize:Number=100;

		public function Main() {
			// constructor code
			gotoEstado(ESTADO_PREINIT);
			addEventListener(Event.ADDED_TO_STAGE,init);
		}
		
		public function init(e:Event=null) {
			removeEventListener(Event.ADDED_TO_STAGE,init);
			gotoEstado(ESTADO_INIT);
		}
		public function end(e:Event=null) {
			NativeApplication.nativeApplication.removeEventListener(Event.EXITING, end);
			if (device!=null) {
				trace("finalizando kinect");
				device.stop();
				//device.removeEventListener(UserEvent.USERS_MASK_IMAGE_UPDATE, camUpdate);
				//device.removeEventListener(CameraImageEvent.RGB_IMAGE_UPDATE, camUpdate);
				//stage.removeEventListener(Event.ENTER_FRAME, camUpdate);
				device.removeEventListener(UserEvent.USERS_ADDED, playerEnters);
				device.removeEventListener(UserEvent.USERS_REMOVED, playerExits);
				device.dispose();
			}
			if (so!=null) {
				// guardar lista top-ten
				so.flush();
				so.close();
				so=null;
			}
		}
		
		// ---------------------------------------------------------------------------------------
		
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
					// poner pantalla completa
					if (flash.system.Capabilities.isDebugger)
					{
						stage.displayState=StageDisplayState.FULL_SCREEN_INTERACTIVE;
						stage.scaleMode=StageScaleMode.SHOW_ALL;
						//stage.scaleMode=StageScaleMode.NO_BORDER;
					}
					//stage.align=""; // center v, center h
					stage.align=StageAlign.TOP_LEFT;
					NativeApplication.nativeApplication.addEventListener(Event.EXITING, end);
					stage.addEventListener(KeyboardEvent.KEY_DOWN, tecla);
					
					//explicitScaleX=stage.stageWidth/explicitWidth;
					//explicitScaleY=stage.stageHeight/explicitHeight;
					//if (explicitScaleX>explicitScaleY) explicitScaleY=explicitScaleX; else explicitScaleX=explicitScaleY;
					//explicitStageWidth=stage.stageWidth;
					//explicitStageHeight=stage.stageHeight;
					
					// ajustar al alto fijo de 576 respecto al de camara original de 480
					explicitScaleY=explicitHeight/480;
					explicitScaleX=explicitScaleY;
					explicitStageWidth=stage.stageWidth;
					explicitStageHeight=stage.stageHeight;
					
					// preparar videos
					nc=new NetConnection();
					nc.connect(null);
					ns=new NetStream(nc);
					ns.client=this;
					ns.addEventListener(NetStatusEvent.NET_STATUS, netStatus);
					ns2=new NetStream(nc);
					ns2.client=this;
					
					// leer top ten
					leerTopTen();
					// generar "scores.txt"
					exportarTopTen();
					
					// iniciar kinect
					if (Kinect.isSupported()) {
						device=Kinect.getDevice();
						var settings:KinectSettings=new KinectSettings();
						//settings.userMaskEnabled=true;
						//settings.userMaskResolution=new Point(320,240); //asegurar resolucion fija
						settings.rgbEnabled=true;
						settings.rgbResolution=new Point(640,480);
						//new Point(explicitWidth,explicitHeight);
						
						//device.addEventListener(UserEvent.USERS_MASK_IMAGE_UPDATE, camUpdate);
						device.addEventListener(CameraImageEvent.RGB_IMAGE_UPDATE, camRgbUpdate);
						
						settings.skeletonEnabled=true;
						
						//stage.addEventListener(Event.ENTER_FRAME, camUpdate);
						device.addEventListener(UserEvent.USERS_ADDED, playerEnters);
						device.addEventListener(UserEvent.USERS_REMOVED, playerExits);
						device.start(settings);
						trace("Kinect iniciada");
						
						// iniciar imagen de camara
						camara=new Bitmap();
						camara.scaleX=explicitScaleX;
						camara.scaleY=explicitScaleY;
						camara.x=0;
						camara.y=0;
						//camara.x=(stage.stageWidth-(explicitWidth*camara.scaleX))*0.5;
						//camara.y=(stage.stageHeight-(explicitHeight*camara.scaleY))*0.5;
						camara_holder.addChild(camara);
						camara_holder.visible=false;
						
						esqueleto_holder.scaleX=camara.scaleX;
						esqueleto_holder.scaleY=camara.scaleY;
						esqueleto_holder.x=camara_holder.x;
						esqueleto_holder.y=camara_holder.y;
						esqueleto_holder.visible=false;
						
						/*
						// iniciar mascara de usuario
						sombra=new Bitmap();
						sombra.scaleX=stage.stageWidth/320;
						sombra.scaleY=stage.stageHeight/240;
						sombra.transform.colorTransform=new ColorTransform(0,0,0,0.2); // negro, alpha
						sombra.x=(stage.stageWidth-(320*sombra.scaleX))*0.5;
						sombra.y=(stage.stageHeight-(240*sombra.scaleY))*0.5;
						sombra_holder.addChild(sombra);
						//*/
						
						// inicializacion timerJuego
						timerJuego=new Timer(1000);
						timerJuego.addEventListener(TimerEvent.TIMER, timerJuegoTick);
						
						// inicializacion completada
						gotoEstado(ESTADO_WAIT);
					} else {
						trace("Kinect no conectada");
						alert_ErrorKinect.visible=true;
					}
				break;
				case this.ESTADO_WAIT:
					// por si se fué sin foto
					if (miniFoto!=null) {
						// liberar foto
						miniFoto.bitmapData.dispose();
						this.removeChild(miniFoto);
						miniFoto=null;
					}
					// perder jugador anterior
					trace("en espera");
					//if (sombra!=null) sombra.bitmapData=null; //vaciar frame anterior
					currentUserId=-1;
					camara_holder.visible=false;
					video.attachNetStream(ns);
					ns.play(video_espera);
					mostrarTopTen();
					toptenArea.visible=true;
					//playArea.removeChildren();
				break;
				case this.ESTADO_DETECTEDINI:
					video.attachNetStream(ns);
					ns.play(video_preparados);
					videoLateral.attachNetStream(ns2);
					ns2.play(video_jugando);
					// post pasar al estado detected normal
					TweenLite.delayedCall(video_preparados_time,gotoEstado,[ESTADO_DETECTED]);
				break;
				case this.ESTADO_DETECTED:
					// mostrar video seq01
					trace("detectado")
					playArea.removeChildren();
					camara_holder.visible=true;
					// reiniciar contadores de partida
				break;
				case this.ESTADO_JUGANDO:
					camara_holder.visible=true;
					playArea.addChild(this.espadaB);
					playArea.addChild(this.espada);
					playArea.addChild(areaEsferas);
					esqueleto_holder.visible=false;
					espada.visible=true;
					espadaB.visible=false;
					this.nivel=0;
					this.pendientes=0;
					this.puntos=0;
					this.tiempo=this.TIEMPO_JUEGO;
					marcadorTiempo.texto.text=tiempo.toString();
					marcadorPuntos.text=puntos.toString();
					timerJuego.reset();
					timerJuego.start();
					TweenLite.delayedCall(1,nextLevel);
					//nextLevel();
				break;
				case this.ESTADO_FIN:
					//TweenLite.to(marcadorPuntos,1,{x:(explicitStageWidth-marcadorPuntos.width)*0.5, y:(explicitStageHeight-marcadorPuntos.height)*0.5});
					var t:Date=new Date();
					this.gameId=((((t.fullYear*100+t.month+1)*100+t.date)*100+t.hours)*100+t.minutes)*100+t.seconds;
					var puesto:Number=this.calcularPosicion(this.puntos);
					//guardarTopTen(this.puntos, this.gameId, t);
					marcadorPosicionFin.text=puesto.toString();
					marcadorPuntos.text=puntos.toString();
					marcadorPuntosFin.text=this.puntos.toString();
					var tf:DateTimeFormatter=new DateTimeFormatter("es_ES");
					tf.setDateTimePattern("dd/MMMM/yyyy");
					marcadorFechaFin.text=tf.format(t);
				break;
				case this.ESTADO_TOPTEN:
					//playArea.removeChildren();
					//mostrarTopTen();
				break;
				default: break;
			}
		}
		
		public function salirEstado(e:Number):Boolean {
			switch (e) {
				case this.ESTADO_WAIT:
					video.attachNetStream(null);
					ns.play(null);
					toptenArea.visible=false;
				break;
				case this.ESTADO_DETECTEDINI:
					TweenLite.killDelayedCallsTo(gotoEstado);
					video.attachNetStream(null);
					ns.play(null);
				break;
				case this.ESTADO_JUGANDO:
					timerJuego.stop();
					esqueleto_holder.visible=false;
					espada.visible=false;
					this.nivel=0;
					this.pendientes=0;
					areaEsferas.removeChildren();
					playArea.removeChildren();
					videoLateral.attachNetStream(null);
					ns2.play(null);
					//SoundMixer.stopAll();
				break;
				case this.ESTADO_TOPTEN:
					if (miniFoto!=null) {
						// liberar foto
						miniFoto.bitmapData.dispose();
						this.removeChild(miniFoto);
						miniFoto=null;
					}
				break;
				default:
				break;
			}
			return true; // por defecto, se permite el cambio de estado
		}
		
		// -----------------------------------------------------------------------------------------

		
		public function tecla(e:KeyboardEvent=null) {
			/*
			if (e.keyCode==Keyboard.RIGHT || e.keyCode==Keyboard.SPACE) {
				if (estado<this.totalFrames)
					gotoEstado(estado+1);
				else gotoEstado(this.ESTADO_WAIT);
			}
			if (e.keyCode==Keyboard.LEFT) {
				if (estado>this.ESTADO_WAIT)
					gotoEstado(estado-1);
			}
			//*/
			if (e.ctrlKey && e.keyCode==Keyboard.BACKSPACE) {
				// borrar los scores
				scores=new Array();
				if (so!=null) {
					so.data.scores=scores;
					// guardar lista top-ten
					so.flush();
					exportarTopTen();
				}
			}
			
			
			if (e.ctrlKey) {
				if (e.keyCode==Keyboard.RIGHT || e.keyCode==Keyboard.UP) {
					oldframes++;
					if (so!=null) {
						so.data.oldframes;
						so.flush();
					}
					
				}
				if (e.keyCode==Keyboard.LEFT || e.keyCode==Keyboard.DOWN) {
					if (oldframes>0) {
						oldframes--;
						if (so!=null) {
							so.data.oldframes;
							so.flush();
						}
					}
				}
			}
			
			if (e.keyCode==Keyboard.BACKSPACE) gotoEstado(this.ESTADO_WAIT); // reset
			
			if (e.keyCode==Keyboard.ENTER || e.keyCode==Keyboard.SPACE) {
				if (estado==this.ESTADO_DETECTED) {
					// iniciar juego (SOLO DEBE HABER 1 DETECTADO)
					if (device.users.length==1) manosArriba(device.users[0].userID);
				} else if (estado==this.ESTADO_FIN) {
					// capturar foto e ir a topten
					if (miniFoto!=null) {
						// guardar en top ten
						var t:Date=new Date();
						guardarTopTen(this.puntos, this.gameId, t);
						guardarFoto(this.gameId,miniFoto.bitmapData);
					}
					gotoEstado(this.ESTADO_TOPTEN);
				} else if (estado==this.ESTADO_TOPTEN) {
					gotoEstado(this.ESTADO_WAIT);
				}
			}
			
			//if (e.keyCode==Keyboard.T) gotoEstado(this.ESTADO_TOPTEN);
			
			if (e.keyCode==Keyboard.ESCAPE) NativeApplication.nativeApplication.activeWindow.close();
		}
		
		// -----------------------------------------------------------------------------------------
		
		public function onMetaData(e){ }//trace(e); }
		public function onCuePoint(e){ }//trace(e); }
		public function onXMPData(infoObject:Object):void {}
		public function onPlayStatus(status:Object):void {}
		public function netStatus(event:NetStatusEvent):void  { 
			if ((event.target as NetStream)!=ns) return; // solo bucle o salto si es el ns principal
			//trace(event.info.code);  // this will handle any events that are fired when the video is playing back  
			switch(event.info.code)  //  switch statement to handle the various events with the NetConnection  
			{ 
				case "NetStream.Play.Stop":  // when you reach the end of the video
					if (this.estado==this.ESTADO_DETECTEDINI) gotoEstado(this.ESTADO_DETECTED);
					if (this.estado==this.ESTADO_WAIT) ns.seek(0);
				break;
				default:
				break;
			}
		}
		// -----------------------------------------------------------------------------------------
		
		public function timerJuegoTick(e:Event) {
			if (this.estado!=this.ESTADO_JUGANDO) {
				// si no jugando, detener el reloj
				tiempo=0;
				timerJuego.stop();
				return;
			}
			tiempo--;
			marcadorTiempo.texto.text=tiempo.toString();
			(new SoundContador()).play();
			if (tiempo==0) {
				timerJuego.stop();
				gotoEstado(this.ESTADO_FIN);
			}
		}
		
		public function sumaPuntos(p:Number=0) {
			this.puntos+=p;
			if (marcadorPuntos!=null) {
				marcadorPuntos.text=puntos.toString();
			}
		}
		
		// -----------------------------------------------------------------------------------------
		
		public function camRgbUpdate(e:CameraImageEvent) {
			oldcam.push(e.imageData.clone());
			if (oldcam.length>oldframes) {
				var bd:BitmapData=(oldcam.shift() as BitmapData);
				camara.bitmapData=bd.clone();
				bd.dispose();
			}
			// comprobar usuarios (que ya estaban de antes)
			var users:Vector.<User>=null;
			users=device.users;
			if (users.length>0) {
				var user:User=null; // para almacenar usuario actual
				// tenemos usuarios
				if (estado==this.ESTADO_WAIT && currentUserId==-1) {
					// auto-detectar usuario de nuevo
					playerEnters(new UserEvent(UserEvent.USERS_ADDED,false,false,users));
				} else if (estado==this.ESTADO_DETECTED) {
					for each(var u:User in users) {
						// detectar MANOS ARRIBA para Iniciar Partida
						detectarManosArriba(u);
					} // for each user
				} else if (estado==this.ESTADO_JUGANDO) {
					for each (var us:User in users) {
						if (us.userID==this.currentUserId) {user=us;break;}
					}
					//esqueleto_holder.graphics.clear();
					if (user!=null && user.hasSkeleton) {
							// right
							var rini:SkeletonJoint=user.skeletonJoints[user.skeletonJointNameIndices["right_elbow"]];
							//esqueleto_holder.graphics.beginFill(0xFF0000, rini.positionConfidence);
							//esqueleto_holder.graphics.drawCircle(rini.position.rgb.x, rini.position.rgb.y, 5);
							//esqueleto_holder.graphics.endFill();
							
							var rfin:SkeletonJoint=user.skeletonJoints[user.skeletonJointNameIndices["right_hand"]];
							//esqueleto_holder.graphics.beginFill(0xFF0000, rfin.positionConfidence);
							//esqueleto_holder.graphics.drawCircle(rfin.position.rgb.x, rfin.position.rgb.y, 5);
							//esqueleto_holder.graphics.endFill();
							
							var rdir:Vector3D=new Vector3D(
										rfin.position.world.x-rini.position.world.x,
										rfin.position.world.y-rini.position.world.y,
										rfin.position.world.z-rini.position.world.z);
							var rdir2d:Vector3D=new Vector3D(rdir.x,rdir.y);
							var rangleZ:Number=90-(Math.atan2(rdir.y,rdir.x)*180/Math.PI);
							//rangleZ+=(rfin.position.world.x>rini.position.world.x)?(-45):45;
							
							// left
							var lini:SkeletonJoint=user.skeletonJoints[user.skeletonJointNameIndices["left_elbow"]];
							//esqueleto_holder.graphics.beginFill(0xFF0000, lini.positionConfidence);
							//esqueleto_holder.graphics.drawCircle(lini.position.rgb.x, lini.position.rgb.y, 5);
							//esqueleto_holder.graphics.endFill();
							
							var lfin:SkeletonJoint=user.skeletonJoints[user.skeletonJointNameIndices["left_hand"]];
							//esqueleto_holder.graphics.beginFill(0xFF0000, lfin.positionConfidence);
							//esqueleto_holder.graphics.drawCircle(lfin.position.rgb.x, lfin.position.rgb.y, 5);
							//esqueleto_holder.graphics.endFill();
							
							var ldir:Vector3D=new Vector3D(
										lfin.position.world.x-lini.position.world.x,
										lfin.position.world.y-lini.position.world.y,
										lfin.position.world.z-lini.position.world.z);
							var ldir2d:Vector3D=new Vector3D(ldir.x,ldir.y);
							var langleZ:Number=90-(Math.atan2(ldir.y,ldir.x)*180/Math.PI);
							//langleZ+=(lfin.position.world.x>lini.position.world.x)?(-45):45;
							
							// final
							var manos:Vector3D=new Vector3D(
										lfin.position.world.x-rfin.position.world.x,
										lfin.position.world.y-rfin.position.world.y,
										lfin.position.world.z-rfin.position.world.z);
							
							var finalpos:Point;
							var finalAngle:Number;
							var finalScale:Number;
							/*
							if (manos.length<rdir.length) { // juntas ... media
								finalpos=new Point((rfin.position.rgb.x+lfin.position.rgb.x)*0.5*camara.scaleX,
														 (rfin.position.rgb.y+lfin.position.rgb.y)*0.5*camara.scaleY);
								finalAngle=(langleZ+rangleZ)*0.5;
								finalScale=(Math.abs(rdir2d.length/rdir.length)+Math.abs(ldir2d.length/ldir.length))*0.5;
							} else
							//*/
							{ // separadas ... solo derecha
								finalpos=new Point(rfin.position.rgb.x*explicitScaleX,rfin.position.rgb.y*explicitScaleY);
								finalAngle=rangleZ;
								//finalScale=Math.max(Math.abs(rdir2d.x),Math.abs(rdir2d.length-rdir2d.y))/Math.abs(rdir.length);
								//finalScale=(1-Math.abs(rdir.y/rdir.length));
								finalScale=Math.abs(rdir2d.length/rdir.length);
							}
							
							// prev pos
							var px:Number=espada.x;
							var py:Number=espada.y;
							var pr:Number=espada.rotation;
							var ps:Number=espada.scaleX;
							// set espada pos
							var smooth:Number=0.75;
							var ismooth:Number=1-smooth;
							espada.x=finalpos.x;
							espada.y=finalpos.y;
							if (Math.abs(finalAngle-espada.rotation)>180) finalAngle-=360;
							espada.rotation=(espada.rotation*smooth)+(finalAngle*ismooth);
							espada.scaleX=espada.scaleY=(espada.scaleX*smooth)+(finalScale*ismooth);
							// set espadaB pos
							// a mitad camino entre posicion anterior y actual de la espada visible
							espadaB.x=(espada.x+px)*0.5;
							espadaB.y=(espada.y+py)*0.5;
							espadaB.rotation=(espada.rotation+pr)*0.5;
							espadaB.scaleX=espadaB.scaleY=(espada.scaleX+ps)*0.5;
							
							// check PISAR BALDOSAS
							var pieL:SkeletonJoint=user.skeletonJoints[user.skeletonJointNameIndices["left_foot"]];
							var pieR:SkeletonJoint=user.skeletonJoints[user.skeletonJointNameIndices["right_foot"]];
							var pisando:Boolean=false;
							for (var bald:int=1;bald<=5;bald++) {
								var nombre:String="b"+bald.toString();
								var baldosa:Baldosa=(this.getChildByName(nombre) as Baldosa);
								if (baldosa!=null) {
									if (baldosa.encendida()) {
										if (   (pieL.position.rgb.x*explicitScaleX+camara_holder.x>baldosa.rect.left && pieL.position.rgb.x*explicitScaleX+camara_holder.x<baldosa.rect.right)
											|| (pieR.position.rgb.x*explicitScaleX+camara_holder.x>baldosa.rect.left && pieR.position.rgb.x*explicitScaleX+camara_holder.x<baldosa.rect.right)) {
											// pisando baldosa (con pie derecho o izquierdo)
											pisando=true;
											baldosa.setPisada(true);
										}
										else baldosa.setPisada(false);
									}
								}
							}
							espada.setCorta(pisando);
							
					} // if user hasSkeleton
				} else if (estado==ESTADO_FIN) {
					for each (var usf:User in users) {
						if (usf.userID==this.currentUserId) {user=usf;break;}
					}
					if (user!=null && user.hasSkeleton) {
						// mostrar mini foto
						if (miniFoto==null) {
							miniFoto=new Bitmap(new BitmapData(fotoSize,fotoSize));
							miniFoto.scaleX=miniFoto.scaleY=foto_holder.scaleX;
							miniFoto.x=foto_holder.x;
							miniFoto.y=foto_holder.y;
							addChild(miniFoto);
						}
						var cabeza:SkeletonJoint=user.skeletonJoints[user.skeletonJointNameIndices["head"]];
						var area:Rectangle=new Rectangle(cabeza.position.rgb.x-fotoSize*0.5,
														 cabeza.position.rgb.y-fotoSize*0.5,
														 fotoSize,fotoSize);
						miniFoto.bitmapData.copyPixels(camara.bitmapData,area,new Point(0,0));
					}
				} // estados con usuarios visibles
			} else {
				// si no hay users... (nadie?) volver a wait (excepto mientras se muestra el topten)
				if (estado!=this.ESTADO_WAIT && estado!=this.ESTADO_TOPTEN) gotoEstado(ESTADO_WAIT);
			}
		}

		
		public function playerEnters(e:UserEvent=null) {
			// si no tenemos ya un jugador activo
			if (currentUserId==-1) {
				// aceptar usuario como jugador actual
				// (supongo que el ultimo de la lista)
				var u:User=e.users[e.users.length-1];
				if (u!=null) {
					currentUserId=u.userID;
					gotoEstado(ESTADO_DETECTEDINI);
				}
			}
		}
		
		// ---------------------------------------------------------------------------------------
		
		public function playerExits(e:UserEvent=null) {
			// si teniamos jugador
			if (currentUserId!=-1) {
				// lista de jugadores perdidos...
				for each(var u:User in e.users) {
					if (u.userID==currentUserId) { // si el actual esta en la lista de perdidos
						// perder jugador
						currentUserId=-1;
						gotoEstado(ESTADO_WAIT);
					}
					// vaciarlo de la lista de userHist (de deteccion de saltos)
					for each(var uh:Object in userHist) {
						if (uh.userId==u.userID) {
							userHist.splice(userHist.indexOf(uh),1);
							break;
						}
					}
				}
			}
		}
		
		/*
		public function detectarSalto(u:User) {
			var hist:Object=null;
			for each(var uh:Object in userHist) { // buscar su userHist (si existe)
				if (uh.userId==u.userID) {
					hist=uh; break;
				}
			}
			var val:Number=(u.position.depth.y+u.head.position.depth.y)*0.5;
			val=u.torso.position.depth.y;
			if (hist==null) { // si no existe, guardar nuevo
				hist=new Object();
				hist.userId=u.userID;
				hist.median=val; // valor unico, media actual
				hist.values=1; // solo un valor analizados (instante 1)
				hist.max=hist.min=hist.median; // valores max y min, el actual (y unico)
				hist.imax=hist.imin=1; // se produjo (el max y el min), en el instante 1;
				userHist.push(hist);
			} else { // actualizar datos
				hist.median=((hist.median*hist.values)+val)/(hist.values+1);
				hist.values++;
				if (val>hist.max) {hist.max=val;hist.imax=hist.values}
				if (val<hist.min) {hist.min=val;hist.imin=hist.values}
			}
		
			// detectar salto
			var gap:Number=(hist.max-hist.min);
			var ratio:Number=0.3;
			if (hist.values>=(stage.frameRate*0.5)) { //(al menos lleve medio segundo calculando medias) ???
				if (gap>(hist.median*ratio)) {
					if (hist.imax < hist.imin) jumped(u.userID); // salto // {else jumped(-1); // caida
				}
				userHist.splice(userHist.indexOf(hist),1);
			}
		}
		
		public function jumped(jumpUserId:uint) {  //e:KinectMovementEvent=null) { //KinectMovementEven //ActionEventDispatcher
			if (estado==this.ESTADO_DETECTED) {
				currentUserId=jumpUserId; // tomar a quien salta, como jugador actual
				trace("JUMP: "+jumpUserId);
				gotoEstado(ESTADO_TIRO);
			}
		}
		//*/
		
		public function detectarManosArriba(u:User) {
			var hist:Object=null;
			for each(var uh:Object in userHist) { // buscar su userHist (si existe)
				if (uh.userId==u.userID) {hist=uh; break;}
			}
			var val:Number;
			// altura media de ambas manos
			val=((u.leftHand.position.depth.y)+(u.rightHand.position.depth.y))*0.5;
			val=val-u.neck.position.depth.y; // distancia al cuello (>0 abajo...  <0 ariba)

			if (hist==null) { // si no existe, guardar nuevo
				hist=new Object();
				hist.userId=u.userID;
				hist.acum=val;		// valor unico
				hist.median=val; // valor unico, media actual
				hist.values=1; // solo un valor analizados (instante 1)
				//hist.max=hist.min=hist.median; // valores max y min, el actual (y unico)
				//hist.imax=hist.imin=1; // se produjo (el max y el min), en el instante 1;
				userHist.push(hist);
			} else { // actualizar datos
				hist.acum+=val; // agrego valor actual
				hist.values++;
				hist.median=hist.acum/hist.values;
				//if (val>hist.max) {hist.max=val;hist.imax=hist.values}
				//if (val<hist.min) {hist.min=val;hist.imin=hist.values}
			}
		
			// detectar manos arriba
			//var gap:Number=(hist.max-hist.min);
			var ratio:Number=-10; // distancia minima necesaria (en pixels)
			if (hist.values>=(stage.frameRate*0.5)) { //(al menos lleve medio segundo calculando medias) ???
				if (hist.median < ratio) manosArriba(u.userID); // manos arriba // else  manos abajo
				userHist.splice(userHist.indexOf(hist),1); // eliminar calculos almacenados de este usuario
			}
		}
		
		public function manosArriba(userId:uint) {  //e:KinectMovementEvent=null) { //KinectMovementEven //ActionEventDispatcher
			if (estado==this.ESTADO_DETECTED) {
				currentUserId=userId; // tomar a quien sube las manos, como jugador actual
				trace("MANOS ARRIBA: "+userId);
				gotoEstado(this.ESTADO_JUGANDO);
			}
		}
		
		// ---------------------------------------------------------------------------------------
		//                                         JUGANDO
		
		public function checkLevel(e:EsferaBase) {
			if (e!=null) {
				// post eliminar grafico
				if (e.parent!=null) e.parent.removeChild(e);
				pendientes-=1;
				if (pendientes<=0) nextLevel(); //TweenLite.delayedCall(1,nextLevel);
			}
		}
		public function nextLevel() {
			areaEsferas.removeChildren();
			if (this.estado!=this.ESTADO_JUGANDO) return; // solo seguir si se está jugando
			nivel++;
			pendientes=0;
			//if (this.nivel==2) this.nivel=5;
			var e:EsferaBase;
			switch(this.nivel) {
				case 1:
				case 15:
				case 19:
					// crear 2 esferas fijas
					e=new EsferaBase();
					e.area=new Rectangle(0.1,0.1,0.1,0.4);
					pendientes++;
					areaEsferas.addChild(e);
					e=new EsferaBase();
					e.area=new Rectangle(0.7,0.1,0.1,0.4);
					pendientes++;
					areaEsferas.addChild(e);
				break;
				case 2:
				case 11:
					// crear 2 esfera moviles (Verticales)
					e=new EsferaBase();
					e.setPoints([new Point(0.1,0.1), new Point(0.1,0.9)]);
					pendientes++;
					areaEsferas.addChild(e);
					e=new EsferaBase();
					e.setPoints([new Point(0.9,0.9), new Point(0.9,0.1)]);
					pendientes++;
					areaEsferas.addChild(e);
				break;
				case 3:
				case 9:
				case 17:
					// crear muchas (7) fijas
					var c3:Number=6;
					var ml3:Number=0.1;
					var ms3:Number=(0.8)/(c3-1);
					for (var i3:Number=0;i3<c3;i3++) {
						e=new EsferaBase();
						e.area=new Rectangle(ml3+(ms3*i3),0.1,0.0,0.4);
						pendientes++;
						areaEsferas.addChild(e);
					}
				break;
				case 4:
				case 8:
				case 14:
					// crear 2 en circulos
					e=new EsferaBase();
					e.time=0.5;
					e.setPoints([new Point(0.3,0.1),new Point(0.45,0.25), new Point(0.5,0.5),new Point(0.45,0.75), new Point(0.3,0.9),new Point(0.15,0.75), new Point(0.1,0.5),new Point(0.15,0.25)]);
					pendientes++;
					areaEsferas.addChild(e);
					e=new EsferaBase();
					e.time=0.5;
					e.setPoints([new Point(0.7,0.9),new Point(0.85,0.75), new Point(0.9,0.5),new Point(0.85,0.25), new Point(0.7,0.1),new Point(0.55,0.25), new Point(0.5,0.5),new Point(0.55,0.75)]);
					pendientes++;
					areaEsferas.addChild(e);
				break;
				case 5:
				case 10:
				case 16:
					// crear 2 en archos
					e=new EsferaBase();
					e.time=0.5;
					e.setPoints([new Point(0.1,0.3),new Point(0.3,0.15), new Point(0.5,0.1),new Point(0.7,0.15), new Point(0.9,0.3),new Point(0.7,0.15), new Point(0.5,0.1),new Point(0.3,0.15)]);
					pendientes++;
					areaEsferas.addChild(e);
					e=new EsferaBase();
					e.time=0.5;
					e.setPoints([new Point(0.9,0.5),new Point(0.7,0.35), new Point(0.5,0.3),new Point(0.3,0.35), new Point(0.1,0.5),new Point(0.3,0.35), new Point(0.5,0.3),new Point(0.7,0.35)]);
					pendientes++;
					areaEsferas.addChild(e);
				break;
				case 6:
				case 13:
				case 20:
					// crear 6 esfera moviles (Verticales)
					e=new EsferaBase();
					e.setPoints([new Point(0.1,0.1), new Point(0.1,0.9)]);
					pendientes++;
					areaEsferas.addChild(e);
					e=new EsferaBase();
					e.setPoints([new Point(0.2,0.9), new Point(0.2,0.1)]);
					pendientes++;
					areaEsferas.addChild(e);
					e=new EsferaBase();
					e.setPoints([new Point(0.3,0.1), new Point(0.3,0.9)]);
					pendientes++;
					areaEsferas.addChild(e);
					//--
					e=new EsferaBase();
					e.setPoints([new Point(0.7,0.9), new Point(0.7,0.1)]);
					pendientes++;
					areaEsferas.addChild(e);
					e=new EsferaBase();
					e.setPoints([new Point(0.8,0.1), new Point(0.8,0.9)]);
					pendientes++;
					areaEsferas.addChild(e);
					e=new EsferaBase();
					e.setPoints([new Point(0.9,0.9), new Point(0.9,0.1)]);
					pendientes++;
					areaEsferas.addChild(e);
				break;
				case 7:
				case 12:
				case 18:
					// 1 esfera en zig-zag rapida
					e=new EsferaBase();
					e.time=0.5;
					e.setPoints([new Point(0.1,0.1), new Point(0.9,0.1), new Point(0.1,0.7), new Point(0.9,0.7)]);
					pendientes++;
					areaEsferas.addChild(e);
				break;
				default:
					for (var n:int=0;n<(nivel-4);n++) {
						e=new EsferaBase();
						e.area=new Rectangle(0.1,0.1,0.8,0.7);
						pendientes++;
						areaEsferas.addChild(e);
					}
				break;
			}
		}
		
		
		// ---------------------------------------------------------------------------------------
		//                                                TOP TEN
		
		public var scores:Array=new Array();
		public function leerTopTen() {
			if (so==null) {
				so=SharedObject.getLocal("scores_laser","/");
			}
			scores=(so.data.scores as Array);
			if (scores==null) scores=new Array();
			/*
			if (scores==null) {
				scores=new Array();
				for (var i:int=20;i>0;i--) {
					var item:Object={puntos:(100*i), foto:"foto.png", fecha:new Date()};
					scores.push(item);
				}
			}
			//*/
			// config delay frames
			var of:Number=(so.data.oldframes as Number);
			if (!isNaN(of)) oldframes=of;
		}
		
		public function calcularPosicion(puntos:Number):Number {
			// calcular puesto,
			var temp:Array;
			temp=scores.concat();
			var item:Object={puntos:puntos};
			temp.push(item);
			temp=temp.sortOn("puntos", Array.DESCENDING | Array.NUMERIC);
			var posicion:Number=temp.indexOf(item)+1;
			return posicion;
		}
		public function guardarTopTen(puntos:Number, gameId:Number, f:Date) {
			// y guardar en table (con gameId como nombre de jpg)
			// gameId.toString()+".jpg"
			var item:Object={puntos:puntos, foto:gameId.toString()+".jpg", fecha:f};
			trace("guardarTopTen: "+item.puntos+" : "+item.foto+" : "+item.fecha.toString());
			scores.push(item);
			scores=scores.sortOn("puntos", Array.DESCENDING | Array.NUMERIC);
			if (!isNaN(MAX_SCORES)) { // limitar lista de scores
				if (scores.length>MAX_SCORES) scores=scores.slice(0,MAX_SCORES-1); // quedarse SOLO con los MAX_SCORES primeros
			}
			// almacenar en scoreList
			if (so!=null) {
				so.data.scores=scores;
				so.flush();
			}
			exportarTopTen(); // generar archivo TXT con el top-ten
		}
		public function exportarTopTen() {
			// Genera archivo TXT con los datos del top-ten
			leerTopTen(); // estar seguros de estar a la ultima
			var separador:String=",";
			var fin:String=";\n";
			var ruta:File=new File(File.applicationDirectory.nativePath).resolvePath("scores.txt");
			var fs:FileStream=new FileStream();
			fs.open(ruta, FileMode.WRITE);
			fs.truncate();
				for (var i:int=0; i<scores.length; i++) {
					var item:Object=scores[i];
					if (item!=null) {
						fs.writeUTFBytes((i+1).toString()+separador);
						if (item.puntos!=null) fs.writeUTFBytes(item.puntos.toString());
						fs.writeUTFBytes(separador);
						if (item.fecha!=null) {
							var f:Date=item.fecha;
							fs.writeUTFBytes(padNumber(f.date)+"/"+padNumber(f.month+1)+"/"+padNumber(f.fullYear));
							fs.writeUTFBytes(separador);
							fs.writeUTFBytes(padNumber(f.hours)+":"+padNumber(f.minutes)+":"+padNumber(f.seconds));
							fs.writeUTFBytes(separador);
						} else {fs.writeUTFBytes(separador);fs.writeUTFBytes(separador);}
						
						if (item.foto!=null) {
							fs.writeUTFBytes(item.foto);
							//loader.load(new URLRequest("fotos/"+item.foto));
						}
						fs.writeUTFBytes(fin);
					}
				} // for score list
			fs.close();
		}
		
		public function guardarFoto(gameId:Number, foto:BitmapData=null) {
			(new SoundFoto()).play();
			// almacenar en scoreList
			if (so!=null) {
				so.data.scores=scores;
				so.flush();
			}
			var jpgEncoder:JPGEncoder = new JPGEncoder(100);
			var jpgBytes:ByteArray = jpgEncoder.encode(foto);
			
			var myFile:File = (new File(File.applicationDirectory.nativePath)).resolvePath("fotos").resolvePath(gameId.toString()+".jpg");
			var fs:FileStream = new FileStream();
			fs.open(myFile, FileMode.WRITE);
			fs.writeBytes(jpgBytes, 0, jpgBytes.length);
			fs.close(); 
		}
		
		var scoreList:MovieClip=null;
		public function mostrarTopTen() {
			leerTopTen();
			if (scoreList==null) {
				scoreList=new MovieClip();
				toptenArea.addChild(scoreList);
			}
			trace("mostrarTopTen: "+scores.length);
			if (scores.length>0) {
				scoreList.removeChildren();
				TweenMax.killTweensOf(scoreList);
				scoreList.y=this.explicitStageHeight;
				scoreList.addChild(new ScoreHead());
				for (var i:int=0; i<scores.length; i++) {
					var item:Object=scores[i];
					if (item!=null) {
						var si:ScoreItem=new ScoreItem();
						//si.x=this.explicitStageWidth*0.5;
						si.x=0;
						si.y=si.height*scoreList.numChildren;
						scoreList.addChild(si);
						si.puesto.text=(i+1).toString();
						if (item.puntos!=null) si.puntos.text=item.puntos.toString();
						if (item.fecha!=null) {
							var f:Date=item.fecha;
							si.fecha.text=padNumber(f.date)+"/"+padNumber(f.month+1)+"/"+padNumber(f.fullYear);
							si.hora.text=padNumber(f.hours)+":"+padNumber(f.minutes)+"::"+padNumber(f.seconds);
						}
						if (item.foto!=null) {
							var loader:Loader=new Loader();
							loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, ioerror);
							loader.load(new URLRequest("fotos/"+item.foto));
							si.foto.addChild(loader);
							si.foto.scaleX=si.foto.scaleY=0.5;
						}
					}
				} // for score list
				TweenMax.to(scoreList,10,{y:-scoreList.height, ease:Linear.easeNone, repeat:-1});
			} // if score list
		}
		
		public function ioerror(e:Event) {};
		
		public function padNumber(num:Number, digits:Number=2):String {
			var numStr:String = num.toString();
			while(numStr.length<digits) numStr="0"+numStr;
			return numStr;
		}
		
		
		// ---------------------------------------------------------------------------------------
		
		
	}
	
}
