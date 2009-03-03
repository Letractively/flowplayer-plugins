/* * This file is part of Flowplayer, http://flowplayer.org * *Copyright (c) 2008, 2009 Flowplayer Oy * * Released under the MIT License: * http://www.opensource.org/licenses/mit-license.php */package org.flowplayer.controls.button {	import org.flowplayer.controls.Config;    import org.flowplayer.view.AnimationEngine;    import flash.display.MovieClip;	import flash.events.MouseEvent;	/**	 * @author api	 */	public class ToggleFullScreenButton extends AbstractToggleButton {		public function ToggleFullScreenButton(config:Config, animationEngine:AnimationEngine) {			super(config, animationEngine);		}		protected override function getUpStateFaceClassName():String {			return "org.flowplayer.controls.flash.FullScreenOnButton";		}				protected override function getDownStateFaceClassName():String {			return "org.flowplayer.controls.flash.FullScreenOffButton";		}				override protected function onMouseOver(event:MouseEvent):void {			super.onMouseOver(event);		}				override protected function onMouseOut(event:MouseEvent = null):void {			super.onMouseOut(event);		}		override protected function onClicked(event:MouseEvent):void {			super.onClicked(event);			onMouseOut();		}				override protected function get tooltipLabel():String {			return isDown ? config.tooltips.fullscreenExit : config.tooltips.fullscreen;		}	}}