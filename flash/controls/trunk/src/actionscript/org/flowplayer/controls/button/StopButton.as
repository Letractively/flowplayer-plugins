/* * This file is part of Flowplayer, http://flowplayer.org * *Copyright (c) 2008, 2009 Flowplayer Oy * * Released under the MIT License: * http://www.opensource.org/licenses/mit-license.php */package org.flowplayer.controls.button {	import org.flowplayer.controls.Config;	import org.flowplayer.controls.button.AbstractButton;    import org.flowplayer.view.AnimationEngine;		/**	 * @author api	 */	public class StopButton extends AbstractButton {		public function StopButton(config:Config, animationEngine:AnimationEngine) {			super(config, animationEngine);		}        override public function get name():String {            return "stop";        }		protected override function getFaceClassName():String {			return "org.flowplayer.controls.flash.StopButton";		}				override protected function get tooltipLabel():String {			return config.tooltips.stop;		}	}}