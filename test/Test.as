package  {
	
	import flash.display.MovieClip;
	
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
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.net.URLRequest;
	import flash.geom.Vector3D;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import fl.data.DataProvider; 
	import flash.geom.Matrix3D;
	import away3d.core.math.Quaternion;
	
	
	public class Test extends MovieClip {
		
		
		private const NUM_JOINTS_PER_VERTEX:Number=4; // 5 pijama, 4-albornoz, 4-delantal
		
		private var _view:View3D;		
		private var rootPose:SkeletonPose;
		private var indexSelected:int=-1;
		private var indexParent:int=-1;
		
		// elementos a buscar
		private var hero:Mesh;
		private var modelTexture:BitmapTexture;
		private var skeleton:Skeleton;
		
		// poses iniciales
		private var _localPoses:Vector.<JointPose>;
    	private var _bindPoses:Vector.<Matrix3D>;
		
		// ejes
		private var currentAxes:Mesh;
		private var parentAxes:Mesh;
			
		
		public function Test() {
			// constructor code
			addEventListener(Event.ADDED_TO_STAGE,init);
		}
		
		public function init(e:Event) {
			trace("Iniciando Away3D...");
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			//setup the view
			_view = new View3D();
			addChild(_view);
			this.setChildIndex(_view,0); // levar al fondo, para permitir iteraciones con elementos UI
			//setup the camera
			_view.antiAlias=2;
			_view.camera.z = -1000;
			_view.camera.lookAt(new Vector3D(0,0,0));
			_view.camera.y = 300;
			stage.addEventListener(Event.RESIZE, away_onResize);
			away_onResize();
			addEventListener(Event.ENTER_FRAME, away_onEnterFrame);
			
			// load models			
				AssetLibrary.enableParser(AWD2Parser);
				//AssetLibrary.enableParser(MD5MeshParser);
				AssetLibrary.addEventListener(AssetEvent.ASSET_COMPLETE, onAssetComplete);
				AssetLibrary.addEventListener(LoaderEvent.RESOURCE_COMPLETE, onResourceComplete);
				AssetLibrary.addEventListener(LoaderEvent.LOAD_ERROR, onLoadError);
				AssetLibrary.load(new URLRequest("media/a.awd")); 
				
		}
		
		private function away_onResize(event:Event = null):void
		{
			_view.width = stage.stageWidth;
			_view.height = stage.stageHeight;
		}
		
		private function away_onEnterFrame(e:Event):void
		{
			_view.render();
		}
		
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
			//elementsLoaded++;
			// check to see if we have all we need
			//if (elementsLoaded == elementsToLoad) {
				setupScene();
			//}
		}
		
		public function rotateHero(event:MouseEvent) {
			hero.rotationY+=(event.delta*2);
			updateAxes();
		}
		
		// -----------------------------------------------------------------------------------
		private function setupScene():void
		{
			trace("setupScene");
			
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
			trace("Todo cargado...");
			
			// cargar en pantalla
			hero.scale(8);
			hero.castsShadows = true;
			hero.x=hero.y=hero.z = 0;
			_view.scene.addChild(hero);
			stage.addEventListener(MouseEvent.MOUSE_WHEEL, rotateHero);
			
			// fin de la carga
			trace("fin de la carga");
			trace("_______________");
			
			
			// root pose, pose actual
			// localPoses, pose original (bind)
			// bindPoses, matrices originales (no se muy bien para que guardarlas)
			
			var comboData:Array = new Array();
			var joint:SkeletonJoint;
			var jointTemp:SkeletonJoint;
			rootPose = new SkeletonPose();
			
			var bind:Matrix3D;
			var parentBind:Matrix3D=new Matrix3D();
			var globalBind:Matrix3D=new Matrix3D();
			var q1:Quaternion=new Quaternion();
			var q2:Quaternion=new Quaternion();
			var q3:Quaternion=new Quaternion();
			_localPoses = new Vector.<JointPose>(skeleton.numJoints, true);
        	_bindPoses = new Vector.<Matrix3D>(skeleton.numJoints, true);
		
			for (var i:int=0; i<skeleton.numJoints; i++) {
				joint=skeleton.joints[i];
				trace(i+" = "+joint.name);				
				//---------------
				bind = new Matrix3D(joint.inverseBindPose);
				bind.invert();
				_bindPoses[i] = bind;
	
				_localPoses[i]=new JointPose();
				_localPoses[i].orientation = new Quaternion();
				if (joint.parentIndex < 0) {	// root
					//_rootLocalPose = _localPoses[i];
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
				
				// rellenar lista de joints
				comboData.push({label:joint.name, data:i});
			}
			
			// crear root pose como COPIAs de localPoses
			for (var ij:int=0;ij<_localPoses.length;ij++) {
				var tp:JointPose=new JointPose();
				tp.copyFrom(_localPoses[ij]);
				rootPose.jointPoses[ij]=tp;
			}
			// crear idle animation
			var clip:SkeletonClipNode = new SkeletonClipNode();
			clip.addFrame(rootPose, 10); clip.addFrame(rootPose, 10);
			clip.name = "idle";
			var animSet:SkeletonAnimationSet = new SkeletonAnimationSet(NUM_JOINTS_PER_VERTEX); // joins-per-vertex
			animSet.addAnimation(clip);
			var animator:SkeletonAnimator = new SkeletonAnimator(animSet, skeleton);
			hero.animator = animator;
			animator.play("idle");
			
			// crear ejes
			var matRojo:ColorMaterial=new ColorMaterial(0xFF0000);
			var matVerde:ColorMaterial=new ColorMaterial(0x00FF00);
			var matAzul:ColorMaterial=new ColorMaterial(0x00AAFF);
			var boxX:Mesh, boxY:Mesh, boxZ:Mesh;
			// current
			boxX=new Mesh(new CubeGeometry(20,1,1), matRojo);boxX.x=10;
			boxY=new Mesh(new CubeGeometry(1,20,1), matVerde);boxY.y=10;
			boxZ=new Mesh(new CubeGeometry(1,1,20), matAzul);boxZ.z=10;
			currentAxes=new Mesh(new CubeGeometry(1,1,1));
			currentAxes.addChild(boxX);
			currentAxes.addChild(boxY);
			currentAxes.addChild(boxZ);
			currentAxes.visible=false;
			_view.scene.addChild(currentAxes);
			// parent
			boxX=new Mesh(new CubeGeometry(10,1,1), matRojo);boxX.x=5;
			boxY=new Mesh(new CubeGeometry(1,10,1), matVerde);boxY.y=5;
			boxZ=new Mesh(new CubeGeometry(1,1,10), matAzul);boxZ.z=5;
			parentAxes=new Mesh(new CubeGeometry(1,1,1));
			parentAxes.addChild(boxX);
			parentAxes.addChild(boxY);
			parentAxes.addChild(boxZ);
			parentAxes.visible=false;
			_view.scene.addChild(parentAxes);
			
			// activar comboBox
			comboJoints.dataProvider = new DataProvider(comboData); 
			comboJoints.addEventListener(Event.CHANGE, changeHandler); 
			bReset.addEventListener(MouseEvent.CLICK, resetHandler);
			bResetAll.addEventListener(MouseEvent.CLICK, resetAllHandler);
			bParent.addEventListener(MouseEvent.CLICK, selectParentHandler);
			sX.addEventListener(Event.CHANGE, updateRotations);
			sY.addEventListener(Event.CHANGE, updateRotations);
			sZ.addEventListener(Event.CHANGE, updateRotations);
			stX.addEventListener(Event.CHANGE, updateRotations);
			stY.addEventListener(Event.CHANGE, updateRotations);
			stZ.addEventListener(Event.CHANGE, updateRotations);
			cAbsolute.addEventListener(Event.CHANGE, changeHandler);
			bX.addEventListener(MouseEvent.CLICK, bXclick);
			trace("_______________");
		}
		
		public function changeHandler(event:Event=null):void {
			if (comboJoints.selectedItem==null) return;
			trace(comboJoints.selectedItem.data+" = "+comboJoints.selectedItem.label);
			this.indexSelected=comboJoints.selectedItem.data;
			
			
			this.indexParent=-1;
			tParent.text="";
			if (this.indexSelected!=-1) {
				var sj:SkeletonJoint=skeleton.jointFromName(comboJoints.selectedItem.label);
				if (sj!=null && sj.parentIndex>-1) {
					this.indexParent=sj.parentIndex;
					sj=skeleton.joints[this.indexParent];
					tParent.text=sj.name;
				}
			}
			updateAxes();
			updateSliders();
		}
		
		public function selectParentHandler(event:Event) {
			if (this.indexParent!=-1) {
				var buscar:String=tParent.text;
				for (var i = 0; i < comboJoints.length; i++) {
					if (comboJoints.getItemAt(i).label == buscar) {
						comboJoints.selectedIndex=i;
						changeHandler();
						break;
					}
				}
			}
		}
		
		public function resetHandler(event:Event):void {
			if (this.indexSelected!=-1) {
				var orig:JointPose=new JointPose();
				if (!cAbsolute.selected) {
					orig.copyFrom(_localPoses[this.indexSelected]);
				} // else, asign null JointPose(0,0,0-0,0,0)
				rootPose.jointPoses[this.indexSelected]=orig;
				updateAxes();
				updateSliders();
			}
		}
		public function resetAllHandler(event:Event):void {
			var orig:JointPose;
			for (var i:int=0;i<rootPose.jointPoses.length;i++) {
				orig=new JointPose();
				if (!cAbsolute.selected) {
					orig.copyFrom(_localPoses[i]);
				} // else, asign null JointPose(0,0,0-0,0,0)
				rootPose.jointPoses[i]=orig;
			}
			updateAxes();
			updateSliders();
		}
		
		public function updateAxes() {
			if (this.indexSelected!=-1) {
				var index:int=this.indexSelected;
				var matToGlobal:Matrix3D=new Matrix3D(); // inicialmente identidad
				
				// transformacion local
				var jp:JointPose=rootPose.jointPoses[index];
				var sj:SkeletonJoint=skeleton.joints[index];
				
				var q:Quaternion=jp.orientation;
				var t:Vector3D=jp.translation;
				var m:Matrix3D=q.toMatrix3D();
				m.appendTranslation(t.x,t.y,t.z);
				
				//matToGlobal.append(m);
				
				while (sj.parentIndex!=-1) {
					index=sj.parentIndex;
					jp=rootPose.jointPoses[index];
					sj=skeleton.joints[index];
					
					q=jp.orientation;
					t=jp.translation;
					m=q.toMatrix3D();
					m.appendTranslation(t.x,t.y,t.z);
					
					matToGlobal.append(m);
				}
				
				//*
				// aplicar ultima transformacion (global) - del modelo
				q=new Quaternion();
				q.fromEulerAngles(hero.rotationX*Math.PI/180,hero.rotationY*Math.PI/180,hero.rotationZ*Math.PI/180);
				m=q.toMatrix3D();
				matToGlobal.append(m);
				//*/
				//*
				matToGlobal.appendScale(8,8,8);
				//*/
				
				
				// tengo matrix que pasa de local a global
				
				// si agarro la pose local
				jp=rootPose.jointPoses[indexSelected];
				q=jp.orientation;
				t=jp.translation;
				m=q.toMatrix3D();
				m.appendTranslation(t.x,t.y,t.z);
				// y la multiplico por la matrix de local->global
				m.append(matToGlobal);
				// tendré la pose en global

				currentAxes.transform=m;
				currentAxes.position=m.position;
				currentAxes.visible=true;
				
				
				//------------------------------
				// volver ahora... de global a local
				var matToLocal:Matrix3D=new Matrix3D();
				matToLocal.copyFrom(matToGlobal);
				matToLocal.invert();
				
				// si agarro la pose global
				// m
				m.copyFrom(currentAxes.transform);
				t=currentAxes.position.clone();
				//m.appendTranslation(t.x,t.y,t.z);	// en objetos normales, transform ya incluye position
				// y la multiplico por la matrix de global->local (inversa de local->global)
				m.append(matToLocal);
				// tendré la pose en local
				
				parentAxes.transform=m;
				parentAxes.position=m.position;
				//parentAxes.visible=true;
				
				
				// test final, hacer lo mismo con el bone en cuestion
				// (deberia quedar en la misma pose inicial... no moverse del sitio)
				m.copyFrom(currentAxes.transform);
				t=currentAxes.position.clone();
				//m.appendTranslation(t.x,t.y,t.z); 	// en objetos normales, transform ya incluye position
				// y la multiplico por la matrix de global->local (inversa de local->global)
				m.append(matToLocal);
				// tendré la pose en local
			
				jp.orientation.fromMatrix(m)
				jp.translation=m.position;
				
			} else currentAxes.visible=parentAxes.visible=false;
		}
		
		public function updateRotations(event:Event=null) {
			if (this.indexSelected!=-1) {
				//trace("grados: "+sX.value+", "+sY.value+", "+sZ.value);
				var radX:Number=sX.value*Math.PI/180;
				var radY:Number=sY.value*Math.PI/180;
				var radZ:Number=sZ.value*Math.PI/180;
				
				// new final pose
				var jp:JointPose=new JointPose();
				if (!cAbsolute.selected) {
					jp.copyFrom(_localPoses[this.indexSelected]); // from original bindPose
					// new rotation (per axis)
					var q:Quaternion=new Quaternion();
					q.fromEulerAngles(radX,radY,radZ);
					jp.orientation.multiply(jp.orientation,q);
				} else {
					// joint de padre, para obtener matriz de global->local
					var sj:SkeletonJoint=null;
					if (this.indexParent!=-1) sj=skeleton.joints[this.indexParent];
					
					// orientacion final
					var destQ:Quaternion=new Quaternion();
					destQ.fromEulerAngles(radX,radY,radZ);
					var destMat:Matrix3D=destQ.toMatrix3D();
					// matriz de global a local (si tiene padre)
					var glMat:Matrix3D;
					if (sj!=null) { // usar matriz del padre
						glMat=new Matrix3D(sj.inverseBindPose);
					} else {
						glMat=new Matrix3D(); // usar identidad
					}
					// pasar de global (destMat) a local (por medio de glMat)
					destMat.append(glMat);
					
					// orientacion final (como quaternion)
					destQ.fromMatrix(destMat);
					jp.orientation=destQ;
				}
				/*
				q.fromAxisAngle(new Vector3D(1,0,0),radX);
				jp.orientation.multiply(jp.orientation,q);
				q.fromAxisAngle(new Vector3D(0,1,0),radY);
				jp.orientation.multiply(jp.orientation,q);
				q.fromAxisAngle(new Vector3D(0,0,1),radZ);
				jp.orientation.multiply(jp.orientation,q);
				//*/
				// new translation
				if (!cAbsolute.selected) { //(offset)
					jp.translation.x+=stX.value;
					jp.translation.y+=stY.value;
					jp.translation.z+=stZ.value;
				} else { // absolute position
					// joint de padre, para obtener matriz de global->local
					var sj:SkeletonJoint=null;
					if (this.indexParent!=-1) sj=skeleton.joints[this.indexParent];
					// matriz de global a local (si tiene padre)
					var glMat:Matrix3D;
					if (sj!=null) { // usar matriz del padre
						glMat=new Matrix3D(sj.inverseBindPose);
					} else {
						glMat=new Matrix3D(); // usar identidad
					}
					// pasar de global (destMat) a local (por medio de glMat)
					var dest:Vector3D=glMat.transformVector(new Vector3D(stX.value,stY.value,stZ.value))
					jp.translation=dest;
				}

				// set final pose
				rootPose.jointPoses[this.indexSelected]=jp;
				
				updateAxes();
				updateLabels();
			}
		}
		
		public function updateSliders() {
			// calcular grados, a partir de orientacion actual
			if (this.indexSelected!=-1) {
				// ^or*fin
				var origJp:JointPose=new JointPose();
				origJp.copyFrom(_localPoses[this.indexSelected]);
				var origMat:Matrix3D=origJp.orientation.toMatrix3D();
				origMat.invert();
				
				var finJp:JointPose=new JointPose();
				finJp.copyFrom(rootPose.jointPoses[this.indexSelected]);
				var finMat:Matrix3D=finJp.orientation.toMatrix3D();
				
				var diffMat:Matrix3D=new Matrix3D();
				if (!cAbsolute.selected) { // calcular rotacion offset
					diffMat.copyFrom(origMat);
					diffMat.prepend(finMat);
				} else { // mostrar rotacion absoluta
					// joint de padre, para obtener matriz de global->local
					var sj:SkeletonJoint=null;
					if (this.indexParent!=-1) sj=skeleton.joints[this.indexParent];
					
					// matriz de global a local (si tiene padre)
					var glMat:Matrix3D;
					if (sj!=null) { // usar matriz del padre
						glMat=new Matrix3D(sj.inverseBindPose);
					} else {
						glMat=new Matrix3D(); // usar identidad
					}
					glMat.invert();	// invertir (para ir de local a global)					
					finMat.append(glMat);
					diffMat.copyFrom(finMat);
				}
				
				var diffQ:Quaternion=new Quaternion();
				diffQ.fromMatrix(diffMat);
				var diffE:Vector3D=diffQ.toEulerAngles();
				diffE.x*=180/Math.PI;
				diffE.y*=180/Math.PI;
				diffE.z*=180/Math.PI;

				sX.value=diffE.x;
				sY.value=diffE.y;
				sZ.value=diffE.z;
				//trace("grados: "+sX.value+", "+sY.value+", "+sZ.value);
				
				// traslacion (ejes segun padre)
				if (!cAbsolute.selected) { // mostrar offset
					stX.value=finJp.translation.x-origJp.translation.x;
					stY.value=finJp.translation.y-origJp.translation.y;
					stZ.value=finJp.translation.z-origJp.translation.z;
				} else { // mostrar valor absoluto
					var jp:JointPose=rootPose.jointPoses[this.indexSelected];
					var sj:SkeletonJoint=null;
					if (this.indexParent!=-1) sj=skeleton.joints[this.indexParent];
					var glMat:Matrix3D=new Matrix3D();
					if (sj!=null) glMat=new Matrix3D(sj.inverseBindPose);
					glMat.invert();	// para pasar de local a global
					var glPos:Vector3D=glMat.transformVector(jp.translation);
					//glPos.scaleBy(8);
				
					stX.value=glPos.x;
					stY.value=glPos.y;
					stZ.value=glPos.z;
				}
				//*/
				
				updateLabels();
			}
		}
		
		public function updateLabels() {
			tX.text=sX.value.toFixed(2);
			tY.text=sY.value.toFixed(2);
			tZ.text=sZ.value.toFixed(2);
			
			ttX.text=stX.value.toFixed(0);
			ttY.text=stY.value.toFixed(0);
			ttZ.text=stZ.value.toFixed(0);
		}
		
		
		public function bXclick(e:Event=null) {
			if (this.indexSelected!=-1) {
				// a quien se lo aplico (pose)
				var jp:JointPose=rootPose.jointPoses[this.indexSelected];
				// joint de padre, para obtener matriz de global->local
				var sj:SkeletonJoint=null;
				if (this.indexParent!=-1) sj=skeleton.joints[this.indexParent];
				
				// orientacion final
				var destMat:Matrix3D=new Matrix3D(Vector.<Number>([1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]));
				// matriz de global a local (si tiene padre)
				var glMat:Matrix3D;
				if (sj!=null) { // usar matriz del padre
					glMat=new Matrix3D(sj.inverseBindPose);
				} else {
					glMat=new Matrix3D(); // usar identidad
				}
				// pasar de global (destMat) a local (por medio de glMat)
				destMat.append(glMat);
				
				// orientacion final (como quaternion)
				var destQ:Quaternion=new Quaternion();
				destQ.fromMatrix(destMat);
				
				jp.orientation=destQ;
				
				updateAxes();
				updateSliders();
			}
		}
		
		
	}
}
