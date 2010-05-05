/* * This file is part of Flowplayer, http://flowplayer.org * * Copyright (c) 2008 Flowplayer Ltd * * Released under the MIT License: * http://www.opensource.org/licenses/mit-license.php */ package org.flowplayer.controls.button {     import flash.display.DisplayObject;     import flash.display.DisplayObjectContainer;     import flash.display.MovieClip;     import flash.events.Event;     import flash.events.MouseEvent;     import flash.geom.ColorTransform;     import org.flowplayer.controls.config.Config;     import org.flowplayer.controls.DefaultToolTip;     import org.flowplayer.controls.NullToolTip;     import org.flowplayer.controls.ToolTip;     import org.flowplayer.view.AbstractSprite;     import org.flowplayer.view.AnimationEngine;     /**	 * @author api	 */	public class AbstractButton extends AbstractSprite { 		private var _config:Config;        private var _top:DisplayObject;        private var _bottom:DisplayObject;        private var _left:DisplayObject;        private var _right:DisplayObject;		private var _face:DisplayObjectContainer;		protected static const HIGHLIGHT_INSTANCE_NAME:String = "mOver";		private var _tooltip:ToolTip;		private var _animationEngine:AnimationEngine;		public function AbstractButton(config:Config, animationEngine:AnimationEngine) {			_config = config;			_animationEngine = animationEngine;            _face = DisplayObjectContainer(addFaceIfNotNull(createFace()));            _left = DisplayObjectContainer(addFaceIfNotNull(getButtonLeft()));            _right = DisplayObjectContainer(addFaceIfNotNull(getButtonRight()));            _top = DisplayObjectContainer(addFaceIfNotNull(getButtonTop()));            _bottom = DisplayObjectContainer(addFaceIfNotNull(getButtonBottom()));            			enabled = true;			            addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);		}        protected function getButtonLeft():DisplayObject {            return SkinClasses.getButtonLeft();        }        protected function getButtonRight():DisplayObject {            return SkinClasses.getButtonRight();        }        protected function getButtonTop():DisplayObject {            return SkinClasses.getButtonTop();        }        protected function getButtonBottom():DisplayObject {            return SkinClasses.getButtonBottom();        }        public function addFaceIfNotNull(child:DisplayObject):DisplayObject {            if (! child) return child;            return addChild(child);        }        override protected function onResize():void {            // We scale width according to the current height! The aspect ratio of the face is always preserved.            resizeFace();            _left.x = 0;            _left.y = _top.height;            _left.height = height - _top.height - _bottom.height;            _top.x = 0;            _top.y = 0;            _top.width = faceWidth + _left.width + _right.width;            _right.x = _left.width + faceWidth;            _right.y = _top.height;            _right.height = height - _top.height - _bottom.height;            _bottom.x = 0;            _bottom.y = height - bottomEdge;            _bottom.width = faceWidth + _left.width + _right.width;            _height = topEdge + faceHeight + bottomEdge;            _width = leftEdge + faceWidth + rightEdge;         }        protected function resizeFace():void {            if (! _face) return;            _face.x = _left.width;            _face.y = _top.height;            _face.height = height - topEdge - bottomEdge;            _face.scaleX = _face.scaleY;        }        protected function get faceWidth():Number {            return _face.width;        }        protected function get faceHeight():Number {            return _face.height;        }        protected function get rightEdge():Number {            return _right.width;        }        protected function get leftEdge():Number {            return _left.width;        }        protected function get topEdge():Number {            return _top.height;            }        protected function get bottomEdge():Number {            return _bottom.height;        }        private function onAddedToStage(event:Event):void {            toggleTooltip();            onMouseOut();                    }		private function toggleTooltip():void {			if (tooltipLabel) {				if (_tooltip && _tooltip is DefaultToolTip) return;				log.debug("enabling tooltip");				_tooltip = new DefaultToolTip(_config, _animationEngine);			} else {				log.debug("tooltip disabled");				_tooltip = new NullToolTip();			}		}		public function redraw(config:Config):void {			_config = config;			onMouseOut();			toggleTooltip();			_tooltip.redraw(config);		}		public function set enabled(value:Boolean) :void {			buttonMode = value;			var func:String = value ? "addEventListener" : "removeEventListener";            this[func](MouseEvent.ROLL_OVER, onMouseOver);            this[func](MouseEvent.ROLL_OUT, onMouseOut);			this[func](Event.MOUSE_LEAVE, onMouseOut);			this[func](MouseEvent.MOUSE_DOWN, onMouseDown);            this[func](MouseEvent.CLICK, onClicked);			alpha = value ? 1 : 0.5;            doEnable(value);		}		protected function doEnable(enabled:Boolean):void {		}				private function transformColor(disp:DisplayObject, redOffset:Number, greenOffset:Number, blueOffset:Number, alphaOffset:Number):void {			log.debug("transformColor");			if (! disp) return;            var transform:ColorTransform = new ColorTransform( 0, 0, 0, alphaOffset, redOffset, greenOffset, blueOffset, 0);			disp.transform.colorTransform = transform;		}		protected function onMouseOut(event:MouseEvent = null):void {//            if (event && isParent(event.relatedObject as DisplayObject, this)) return;			log.debug("onMouseOut");			hideTooltip();            showMouseOutState(_face);		            resetDispColor(_face.getChildByName(HIGHLIGHT_INSTANCE_NAME));        }        protected function onMouseOver(event:MouseEvent):void {            log.debug("onMouseOver" + _face.getChildByName(HIGHLIGHT_INSTANCE_NAME));            showTooltip();            showMouseOverState(_face);            transformDispColor(_face.getChildByName(HIGHLIGHT_INSTANCE_NAME));        }        protected function showMouseOverState(clip:DisplayObjectContainer):void {		log.debug("showMouseOverState "+ clip);            if (clip is MovieClip) {                log.debug("calling play() on " + clip);                if (MovieClip(clip).currentFrame == 1) {                    MovieClip(clip).play();                }            }			var overClip:DisplayObject = clip.getChildByName(HIGHLIGHT_INSTANCE_NAME);			if ( overClip && overClip is MovieClip )				MovieClip(overClip).gotoAndPlay("over");        }        protected function showMouseOutState(clip:DisplayObjectContainer):void {            if (clip is MovieClip) {                log.debug("calling gotoAndStop(1) on " + clip);                MovieClip(clip).gotoAndStop(1);            }			var overClip:DisplayObject = clip.getChildByName(HIGHLIGHT_INSTANCE_NAME);			if ( overClip && overClip is MovieClip )				MovieClip(overClip).gotoAndStop(1);        }		protected function hideTooltip():void {			_tooltip.hide();		}				protected function showTooltip():void {            if (! tooltipLabel) {                hideTooltip();            }            toggleTooltip();            _tooltip.show(this, tooltipLabel);		}		protected function get tooltipLabel():String {			return null;		}		protected function transformDispColor(disp:DisplayObject):void {			log.debug("mouse over colors", _config.style.buttonOverColorRGBA);			transformColor(disp, _config.style.buttonOverColorRGBA[0], _config.style.buttonOverColorRGBA[1], _config.style.buttonOverColorRGBA[2], _config.style.buttonOverColorRGBA[3]);		}				protected function resetDispColor(disp:DisplayObject):void {			log.debug("normal colors", _config.style.buttonColorRGBA);			transformColor(disp, _config.style.buttonColorRGBA[0], _config.style.buttonColorRGBA[1], _config.style.buttonColorRGBA[2], _config.style.buttonColorRGBA[3]);		}		protected function createFace():DisplayObjectContainer {            return null;		}		protected final function get config():Config {			return _config;		}		protected function onClicked(event:MouseEvent):void {			log.debug("clicked!");			dispatchEvent(new ButtonEvent(ButtonEvent.CLICK));            showTooltip();		}						protected function onMouseDown(event:MouseEvent):void {			var overClip:DisplayObject = _face.getChildByName(HIGHLIGHT_INSTANCE_NAME);			if ( overClip && overClip is MovieClip )				MovieClip(overClip).gotoAndPlay("down");		}    }}