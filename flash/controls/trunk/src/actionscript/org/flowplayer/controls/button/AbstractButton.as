/* * This file is part of Flowplayer, http://flowplayer.org * * Copyright (c) 2008 Flowplayer Ltd * * Released under the MIT License: * http://www.opensource.org/licenses/mit-license.php */ package org.flowplayer.controls.button {     import flash.display.MovieClip;import flash.events.Event;import flash.system.ApplicationDomain;     import flash.utils.getDefinitionByName;import org.flowplayer.controls.Config;     import org.flowplayer.controls.DefaultToolTip;     import org.flowplayer.controls.NullToolTip;     import org.flowplayer.controls.ToolTip;     import org.flowplayer.util.Log;     import org.flowplayer.view.AnimationEngine;	     import flash.display.DisplayObject;     import flash.display.DisplayObjectContainer;     import flash.display.Sprite;     import flash.events.MouseEvent;     import flash.geom.ColorTransform;	/**	 * @author api	 */	public class AbstractButton extends Sprite {		        CONFIG::skin {            private var _buttonClassReferences:SkinClassReferences;        }		private var _config:Config;		private var _face:DisplayObjectContainer;		protected static const HIGHLIGHT_INSTANCE_NAME:String = "mOver";		protected var log:Log = new Log(this);		private var _tooltip:ToolTip;		private var _animationEngine:AnimationEngine;        private var _skinClasses:ApplicationDomain;		public function AbstractButton(config:Config, animationEngine:AnimationEngine) {			_config = config;			_animationEngine = animationEngine;			_face = createFace();			if (_face) {				addChild(_face);            }			enabled = true;			            addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);		}        private function onAddedToStage(event:Event):void {            toggleTooltip();            onMouseOut();                    }		private function toggleTooltip():void {			if (tooltipLabel) {				if (_tooltip && _tooltip is DefaultToolTip) return;				log.debug("enabling tooltip");				_tooltip = new DefaultToolTip(_config, _animationEngine);			} else {				log.debug("tooltip disabled");				_tooltip = new NullToolTip();			}		}		public function redraw(config:Config):void {			_config = config;			onMouseOut();			toggleTooltip();			_tooltip.redraw(config);		}		public function set enabled(value:Boolean) :void {			clickListenerEnabled = value;			buttonMode = value;			var func:String = value ? "addEventListener" : "removeEventListener";			this[func](MouseEvent.MOUSE_OVER, onMouseOver);				this[func](MouseEvent.MOUSE_OUT, onMouseOut);			this[func](MouseEvent.CLICK, onClicked);			alpha = value ? 1 : 0.5;		}		protected function set clickListenerEnabled(enabled:Boolean):void {		}				private function transformColor(disp:DisplayObject, redOffset:Number, greenOffset:Number, blueOffset:Number):void {			log.debug("transformColor");			if (! disp) return;			var transform:ColorTransform = new ColorTransform( 0, 0, 0, 1, redOffset, greenOffset, blueOffset, 0);			disp.transform.colorTransform = transform;		}		protected function onMouseOut(event:MouseEvent = null):void {			log.debug("onMouseOut");			resetDispColor(_face.getChildByName(HIGHLIGHT_INSTANCE_NAME));			hideTooltip();            showMouseOverState(_face);		}        protected function showMouseOverState(clip:DisplayObjectContainer):void {            if (clip is MovieClip) {                log.debug("callingn play() on " + clip);                MovieClip(clip).play();            }        }        protected function showMouseOutState(clip:DisplayObjectContainer):void {            if (clip is MovieClip) {                log.debug("callingn gotoAndStop(1) on " + clip);                MovieClip(clip).gotoAndStop(1);            }        }		protected function onMouseOver(event:MouseEvent):void {			log.debug("onMouseOver");			transformDispColor(_face.getChildByName(HIGHLIGHT_INSTANCE_NAME));			showTooltip();            showMouseOutState(_face);		}				protected function hideTooltip():void {			_tooltip.hide();		}				protected function showTooltip():void {			_tooltip.show(this, tooltipLabel);		}		protected function get tooltipLabel():String {			return null;		}		protected function transformDispColor(disp:DisplayObject):void {			log.debug("mouse over colors", _config.style.buttonOverColorRGB);			transformColor(disp, _config.style.buttonOverColorRGB[0], _config.style.buttonOverColorRGB[1], _config.style.buttonOverColorRGB[2]);		}				protected function resetDispColor(disp:DisplayObject):void {			log.debug("normal colors", _config.style.buttonColorRGB);			transformColor(disp, _config.style.buttonColorRGB[0], _config.style.buttonColorRGB[1], _config.style.buttonColorRGB[2]);		}		protected function createFace():DisplayObjectContainer {            var className:String = getFaceClassName();			var Face:Class = getClass(className);            return new Face();		}		protected function getFaceClassName():String {            return null;        }				protected final function get config():Config {			return _config;		}		protected function onClicked(event:MouseEvent):void {			log.debug("clicked!");			dispatchEvent(new ButtonEvent(ButtonEvent.CLICK));			showTooltip();		}        protected function getClass(name:String):Class {            log.debug("creating skin class " + name);            if (_skinClasses) {                return _skinClasses.getDefinition(name) as Class;            }            return getDefinitionByName(name) as Class;        }                public function set skinClasses(val:ApplicationDomain):void {            _skinClasses = val;        }    }}