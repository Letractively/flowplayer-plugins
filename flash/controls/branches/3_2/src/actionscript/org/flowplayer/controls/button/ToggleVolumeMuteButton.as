/* * This file is part of Flowplayer, http://flowplayer.org * *Copyright (c) 2008, 2009 Flowplayer Oy * * Released under the MIT License: * http://www.opensource.org/licenses/mit-license.php */package org.flowplayer.controls.button {    import flash.display.DisplayObjectContainer;    import flash.display.Sprite;    import flash.events.Event;    import org.flowplayer.controls.config.Config;    import org.flowplayer.view.AnimationEngine;    /**	 * @author api	 */	public class ToggleVolumeMuteButton extends AbstractToggleButton {		public function ToggleVolumeMuteButton(config:Config, animationEngine:AnimationEngine) {			super(config, animationEngine);			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);		}        override public function get name():String {            return "mute";        }		private function onAddedToStage(event:Event):void {			log.debug("adding hit area");			var hitSprite:Sprite = new Sprite();			hitSprite.graphics.beginFill(0, 0);			hitSprite.graphics.drawRect(0, 0, _upStateFace.width, _upStateFace.height);			hitSprite.graphics.endFill();			hitSprite.mouseEnabled = false;			addChild(hitSprite);			hitArea = hitSprite;		}        override protected function createUpStateFace():DisplayObjectContainer {            return DisplayObjectContainer(SkinClasses.getMuteButton());        }        override protected function createDownStateFace():DisplayObjectContainer {            return DisplayObjectContainer(SkinClasses.getUnmuteButton());        }		override protected function get tooltipLabel():String {            if (! config.tooltips) return null;			return isDown ? config.tooltips.unmute : config.tooltips.mute;		}			}}