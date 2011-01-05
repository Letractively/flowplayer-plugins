/* * This file is part of Flowplayer, http://flowplayer.org * * By: Daniel Rossi <electroteque@gmail.com>, Anssi Piirainen <api@iki.fi> Flowplayer Oy * Copyright (c) 2009, 2010 Electroteque Multimedia, Flowplayer Oy * * Released under the MIT License: * http://www.opensource.org/licenses/mit-license.php */package org.flowplayer.bwcheck {    import de.betriebsraum.video.BufferCalculator;    import flash.display.DisplayObject;    import flash.events.NetStatusEvent;    import flash.events.MouseEvent;    import flash.net.NetStream;    import flash.net.NetStreamPlayOptions;    import flash.net.NetStreamPlayTransitions;        import org.flowplayer.controller.ClipURLResolver;    import org.flowplayer.controller.NetStreamClient;    import org.flowplayer.controller.StreamProvider;    import org.flowplayer.model.Clip;    import org.flowplayer.model.ClipEvent;    import org.flowplayer.model.PlayerEvent;    import org.flowplayer.model.Plugin;    import org.flowplayer.model.PluginEventType;    import org.flowplayer.model.PluginModel;    import org.flowplayer.util.PropertyBinder;    import org.flowplayer.view.AbstractSprite;    import org.flowplayer.view.Flowplayer;        import org.flowplayer.ui.Dock;    import org.flowplayer.ui.DockConfig;    import org.flowplayer.ui.AutoHide;    import org.flowplayer.ui.AbstractToggleButton;        import org.osmf.logging.Log;    import org.osmf.net.DynamicStreamingItem;    import org.osmf.net.DynamicStreamingResource;    import org.osmf.net.NetStreamSwitchManager;    import org.osmf.net.NetStreamSwitchManagerWowza;    import org.osmf.net.StreamType;    import org.osmf.net.SwitchingRuleBase;    import org.osmf.net.rtmpstreaming.*;        import org.flowplayer.bwcheck.detect.BandwidthDetectEvent;    import org.flowplayer.bwcheck.detect.BandwidthDetector;    import org.flowplayer.bwcheck.detect.ScreenSizeRule;    import org.flowplayer.bwcheck.detect.StreamSelector;    import org.flowplayer.bwcheck.icons.HDIcon;    import org.flowplayer.bwcheck.config.Config;        public class BitrateProvider extends AbstractSprite  implements ClipURLResolver, Plugin {        private var _config:Config;        private var _netStream:NetStream;        private var _resolveSuccessListener:Function;        private var _failureListener:Function;        private var _clip:Clip;        private var _hasDetectedBW:Boolean = false;        private var _start:Number = 0;        private var _model:PluginModel;        private var _previousStreamName:String;        private var _player:Flowplayer;        private var _resolving:Boolean;        private var _initFailed:Boolean;        private var _playButton:DisplayObject;        private var _provider:StreamProvider;        private var _dynamicOldStreamName:String;        private var _bitrateStorage:BitrateStorage;        private var _streamSelector:StreamSelector;        private var _detector:BandwidthDetector;        private var _switchManager:NetStreamSwitchManager;        private var dsResource:DynamicStreamingResource;        private var _iconDock:Dock;        private var _hdIcon:HDIcon;        public function onConfig(model:PluginModel):void {            log.debug("onConfig(_)");            Log.loggerFactory = new OsmfLoggerFactory();            _config = new PropertyBinder(new Config()).copyProperties(model.config) as Config;            _model = model;            _bitrateStorage = new BitrateStorage(_config.bitrateProfileName, "/");            _bitrateStorage.expiry = _config.cacheExpiry;            log.debug("onConfig(), dynamic " + _config.dynamic);        }        private function applyForClip(clip:Clip):Boolean {            log.debug("applyForClip(), clip.urlResolvers == " + clip.urlResolvers);            if (clip.urlResolvers == null) return false;            var apply:Boolean = clip.urlResolvers.indexOf(_model.name) >= 0;            log.debug("applyForClip? " + apply);            return apply;        }        public function onLoad(player:Flowplayer):void {            log.debug("onLoad()");            _player = player;            _detector = new BandwidthDetector(_model, _config, _player.playlist);            _detector.addEventListener(BandwidthDetectEvent.DETECT_COMPLETE, onDetectorComplete);            _detector.addEventListener(BandwidthDetectEvent.CLUSTER_FAILED, onClusterFailed);            if (_config.switchOnFullscreen) {                _player.onFullscreen(onFullscreen);                _player.onFullscreenExit(onFullscreen);            }            _player.playlist.onBeforeBegin(function(event:ClipEvent):void {                var clip:Clip = event.target as Clip;                if (clip.getCustomProperty("bitrates") != null && clip.getCustomProperty("bitrateStreamingItems") == null) {                 	buildBitrateList(clip);                } else {                	//collect the stream selector when replaying clips in a playlist                    _streamSelector = new StreamSelector(clip.getCustomProperty("bitrateStreamingItems") as Vector.<DynamicStreamingItem>, _player, _config);                }                                if (_hdIcon) {                    if (clip.getCustomProperty("hasHD")) {                    	 _hdIcon.enabled = true;                        //clip.setCustomProperty("hdIndex", aBitrateItem.index);                    } else {                    	_hdIcon.enabled = false;                    }                }                                                     }, applyForClip);                                  _player.playlist.onStart(function(event:ClipEvent):void {                log.debug("onBegin()");                var clip:Clip = event.target as Clip;                init(clip.getNetStream(), clip);                if (_config.dynamic) {                    initQoS(clip.getNetStream(), clip);                }            }, applyForClip);            var autoSwitch:Function = function(enable:Boolean):Function {                return function(event:ClipEvent):void {                    if (! _switchManager) return;                    var newVal:Boolean = _config.dynamic && enable;                    log.debug("setting QOS state to " + newVal);                    _switchManager.autoSwitch = newVal;                }            };            _player.playlist.onPause(autoSwitch(false), applyForClip);            _player.playlist.onStop(autoSwitch(false), applyForClip);            _player.playlist.onStart(autoSwitch(true), applyForClip);            _player.playlist.onResume(autoSwitch(true)), applyForClip;            _player.playlist.onFinish(autoSwitch(false), applyForClip);                                    if (_config.hdIcon) {            	createIconDock();            	_player.onLoad(onPlayerLoad);            }                  _model.dispatchOnLoad();        }                private function createIconDock():void {            if (_iconDock) return;                        _iconDock = Dock.getInstance(_player, _config.dockConfig);            var addIcon:Function = function(icon:DisplayObject, clickCallback:Function):void {                _iconDock.addIcon(icon);                icon.addEventListener(MouseEvent.MOUSE_DOWN, function(event:MouseEvent):void {                    clickCallback(icon);                });                           };                            _hdIcon = new HDIcon(_config.iconConfig, _player.animationEngine);                        addIcon(_hdIcon as DisplayObject, function(icon:DisplayObject):void { toggleHD(icon); });        }                private function toggleHD(icon:DisplayObject):void {        	var hdIcon:AbstractToggleButton = icon as AbstractToggleButton;        	        	//log.error(String(hdIcon.toggle));        }                private function onPlayerLoad(event:PlayerEvent):void {            log.debug("onPlayerLoad() ");            _iconDock.addToPanel();        }                /*        private function fadeIn():void {            this.visible = true;            this.alpha = 0;            _player.setKeyboardShortcutsEnabled(false);            _player.animationEngine.fadeIn(this);        }*/        private function onFullscreen(event:PlayerEvent):void {            if (_player.streamProvider.type == "http") {                log.debug("onFullscreen(), doing progressive download and will not detect again on fullscreen");                return;            }            if (! _config.dynamic) {                log.debug("onFullscreen(), detecting bandwidth");                checkBandwidthIfNotDetectedYet();            }        }        private function alreadyResolved(clip:Clip):Boolean {            return clip.getCustomProperty("bwcheckResolvedUrl") != null;        }        protected function hasDetectedBW():Boolean {            if (! _config.rememberBitrate) return false;            if (_hasDetectedBW) return true;            if (isRememberedBitrateValid()) return true;            return false;        }        public function set onFailure(listener:Function):void {            _failureListener = listener;        }        public function handeNetStatusEvent(event:NetStatusEvent):Boolean {            return true;        }        private function detect():void {            log.debug("connectServer()");            _detector.detect();        }        private function onClusterFailed(event:BandwidthDetectEvent):void {            log.debug("onClusterFailed(), will use default bitrate");            useDefaultBitrate();        }        private function onDetectorComplete(event:BandwidthDetectEvent):void {            log.debug("onDetectorComplete()");            event.stopPropagation();            log.info("\n\n kbit Down: " + event.info.kbitDown + " Delta Down: " + event.info.deltaDown + " Delta Time: " + event.info.deltaTime + " Latency: " + event.info.latency);            _hasDetectedBW = true;            // Set the detected bandwidth            var bandwidth:Number = event.info.kbitDown;            var mappedBitrate:BitrateItem = getMappedBitrate(bandwidth);            log.debug("bandwidth (kbitDown) " + bandwidth);            log.info("mapped to bitrate " + mappedBitrate.bitrate);            rememberBandwidth(bandwidth);            selectBitrate(mappedBitrate, bandwidth);        }        private function get bitrateItems():Vector.<DynamicStreamingItem> {            return streamSelector.bitrates;        }        private function getMappedBitrate(bandwidth:Number = -1):BitrateItem {            if (bandwidth == -1) return streamSelector.getDefaultStream() as BitrateItem;            return streamSelector.getStream(bandwidth) as BitrateItem;        }        private function useDefaultBitrate():void {            log.info("using default bitrate because of an error with the bandwidth check");            selectBitrate(getMappedBitrate(), -1);        }        private function selectBitrate(mappedBitrate:BitrateItem, detectedBitrate:Number = -1):void {            log.debug("selectBitrate()");            dynamicBuffering(mappedBitrate.bitrate, detectedBitrate);            if (_playButton && _playButton.hasOwnProperty("stopBuffering")) {                _playButton["stopBuffering"]();            }            if (_resolving) {                changeStreamNames(mappedBitrate);                _resolveSuccessListener(_clip);                _resolving = false;            } else if (_netStream && (_player.isPlaying() || _player.isPaused())) {                switchStream(mappedBitrate);            } else {                changeStreamNames(mappedBitrate);            }            log.debug("dispatching onBwDone, mapped bitrate: " + mappedBitrate.bitrate + " detected bitrate " + detectedBitrate + " url: " + _clip.url);            _model.dispatch(PluginEventType.PLUGIN_EVENT, "onBwDone", mappedBitrate, detectedBitrate);        }        private function changeStreamNames(mappedBitrate:BitrateItem):void {            _previousStreamName = _clip.url;            var url:String = getClipUrl(_clip, mappedBitrate);            _clip.setResolvedUrl(this, url);            _clip.setCustomProperty("bwcheckResolvedUrl", url);            _clip.setCustomProperty("mappedBitrate", mappedBitrate);            log.debug("mappedUrl " + url + ", clip.url now " + _clip.url);        }        private function switchStream(mappedBitrate:BitrateItem):void {            log.debug("switchStream(), provider type is " + _provider.type);            changeStreamNames(mappedBitrate);            if (_netStream && _netStream.hasOwnProperty("play2") && _provider.type == "rtmp") {                switchStreamDynamic(mappedBitrate);            } else {                log.debug("calling switchStream");                _model.dispatch(PluginEventType.PLUGIN_EVENT, "onStreamSwitchBegin", mappedBitrate, _clip.url, _previousStreamName);                _player.switchStream(_clip);            }        }        private function switchStreamDynamic(bitrate:BitrateItem):void {            log.debug("switchStreamDynamic()");            _netStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);            var options:NetStreamPlayOptions = new NetStreamPlayOptions();            if (_previousStreamName) {                options.oldStreamName = _previousStreamName;                options.transition = NetStreamPlayTransitions.SWITCH;            } else {                options.transition = NetStreamPlayTransitions.RESET;            }            options.streamName = _clip.url;            _dynamicOldStreamName = options.oldStreamName;            log.debug("calling switchStream with Dynamic Switch Streaming, stream name is " + options.streamName);            //_player.switchStream(_clip, options);            _netStream.play2(options);        }        private function getDefaultSwitchingRules(metrics:RTMPNetStreamMetrics):Vector.<SwitchingRuleBase> {            var rules:Vector.<SwitchingRuleBase> = new Vector.<SwitchingRuleBase>();            addRule("bwUp", rules, new SufficientBandwidthRule(metrics));            addRule("bwDown", rules, new InsufficientBandwidthRule(metrics));            addRule("frames", rules, new DroppedFramesRule(metrics));            addRule("buffer", rules, new InsufficientBufferRule(metrics));            addRule("screen", rules, new ScreenSizeRule(metrics, streamSelector, _player, _config));            return rules;        }        private function addRule(prop:String, rules:Vector.<SwitchingRuleBase>, rule:SwitchingRuleBase):void {            if (_config.qos[prop]) {                log.debug("using QoS switching rules " + rule);                rules.push(rule);            }        }        protected function buildBitrateList(clip:Clip):void {            log.debug("buildBitrateList()");            if (clip.getCustomProperty("bitrateItems")) {                log.debug("buildBitrateList(), bitrates already initialized, returning");                return;            }            if (! clip.getCustomProperty("bitrates")) {                return;            }            var items:Array = new Array();            for each(var props:Object in clip.getCustomProperty("bitrates")) {                var bitrate:BitrateItem = new BitrateItem();                for (var key:String in props) {                    if (bitrate.hasOwnProperty(key)) bitrate[key] = props[key];                }                                items.push(bitrate);            }            clip.setCustomProperty("bitrateItems", items);            var streamingItems:Vector.<DynamicStreamingItem> = new Vector.<DynamicStreamingItem>();            for (var i:int = 0; i < items.length; i++) {                var aBitrateItem:BitrateItem = items[i];                aBitrateItem.index = i;                streamingItems.push(aBitrateItem);                                if (aBitrateItem.hd) {                    clip.setCustomProperty("hasHD", true);                    clip.setCustomProperty("hdIndex", aBitrateItem.index);                }            }                        //set the DynamicStreamingItem to the clip to be reused later in the streamselector            clip.setCustomProperty("bitrateStreamingItems", streamingItems);            _streamSelector = new StreamSelector(streamingItems, _player, _config);            log.debug("ordered bitrate list");            for each (var itemInOrder:Object in _streamSelector.bitrates) {                log.debug("item", itemInOrder);            }        }        /**         * Store the detection and chosen bitrate if the rememberBitrate config property is set.         */        protected function rememberBandwidth(bw:int):void {            if (_config.rememberBitrate) {                _bitrateStorage.bandwidth = bw;                log.debug("stored bandwidth " + bw);            }        }        private function isRememberedBitrateValid():Boolean {            log.debug("isRememberedBitrateValid()");            if (! _bitrateStorage.bandwidth) {                log.debug("bandwidth not in SO");                return false;            }            var expired:Boolean = _bitrateStorage.isExpired;            log.debug("is remembered bitrate expired?: " + expired + (expired ? ", age is " + _bitrateStorage.age : ""));            return ! expired;        }        public function resolve(provider:StreamProvider, clip:Clip, successListener:Function):void {            log.debug("resolve " + clip);            if (clip.getCustomProperty("bitrates") == null) {                log.debug("Bitrates configuration not enabled for this clip");                successListener(clip);                return;            }            if (alreadyResolved(clip)) {                log.debug("resolve(): bandwidth already resolved for clip " + clip + ", will not detect again");                successListener(clip);                return;            }            _provider = provider;            _resolving = true;            _resolveSuccessListener = successListener;            init(provider.netStream, clip);            //buildBitrateList(clip);            checkBandwidthIfNotDetectedYet();        }        private function dynamicBuffering(mappedBitrate:Number, detectedBitrate:Number):void {            if (_config.dynamicBuffer) {                _clip.onMetaData(function(event:ClipEvent):void {                    _clip.bufferLength = BufferCalculator.calculate(_clip.metaData.duration, mappedBitrate, detectedBitrate);                    log.debug("Dynamically setting buffer time to " + _clip.bufferLength + "s");                });            }        }        private function checkBandwidthIfNotDetectedYet():void {            if (! applyForClip(_player.playlist.current)) return;            if (hasDetectedBW()) {                var mappedBitrate:BitrateItem = getMappedBitrate(_bitrateStorage.bandwidth);                log.info("using remembered bandwidth " + _bitrateStorage.bandwidth + ", maps to bitrate " + mappedBitrate.bitrate);                selectBitrate(mappedBitrate, _bitrateStorage.bandwidth);            } else if (_initFailed) {                useDefaultBitrate();            } else if (_config.dynamic && !_config.checkOnStart) {                log.info("using dynamic switching with default bitrate ");                selectBitrate(getMappedBitrate(), -1);            } else if (_config.checkOnStart) {                log.debug("not using remembered bandwidth, detecting now");                detect();            }        }        private function init(netStream:NetStream, clip:Clip):void {            log.debug("init(), netStream == " + netStream);            _netStream = netStream;            _clip = clip;            _start = netStream ? netStream.time : 0;            if (netStream && ! (netStream.client is OsmfNetStreamClient)) {                var netStreamClient:OsmfNetStreamClient = new OsmfNetStreamClient(NetStreamClient(netStream.client));                netStreamClient.onTransitionComplete = onTransitionComplete;                netStream.client = netStreamClient;                netStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStreamStatus);            }                        buildBitrateList(clip);        }        private function initQoS(netStream:NetStream, clip:Clip):void {            log.debug("initQoS(), netStream == " + netStream + ", host == " + _detector.host);                        /*            if (dsResource) {                log.debug("initQos(), QoS alsready initialized");                return;            }*/                       //save the streaming resource and load for each clip in the playlist            if (clip.getCustomProperty("bitrateStreamResource")) {            	dsResource = clip.getCustomProperty("bitrateStreamResource") as DynamicStreamingResource;                dsResource.initialIndex = streamSelector.currentIndex;            } else {            	dsResource = null;                dsResource = new DynamicStreamingResource(_detector.host);                    dsResource.streamItems = Vector.<DynamicStreamingItem>(bitrateItems);                dsResource.initialIndex = streamSelector.currentIndex;                dsResource.streamType = _config.live ? StreamType.LIVE : StreamType.RECORDED;                 clip.setCustomProperty("bitrateStreamResource", dsResource);            }                        var metrics:RTMPNetStreamMetrics = new RTMPNetStreamMetrics(netStream);            metrics.resource = dsResource;            _switchManager = new NetStreamSwitchManager(_provider.netConnection, netStream, dsResource, metrics, getDefaultSwitchingRules(metrics));            log.debug("using switch manager " + _switchManager);            _switchManager.autoSwitch = true;            metrics.startMeasurements();        }        private function onNetStreamStatus(event:NetStatusEvent):void {            log.info("onNetStreamStatus() -- " + event.info.code);            switch (event.info.code) {                case "NetStream.Play.Transition":                        log.debug("new item is " + streamSelector.fromName(event.info.details) + ", (" + event.info.details + "), current " + currentItem());                    _model.dispatch(PluginEventType.PLUGIN_EVENT, "onStreamSwitchBegin", streamSelector.fromName(event.info.details), currentItem());                    break;            }        }        private function onTransitionComplete():void {            log.debug("onTransitionComplete(), current index is " + _switchManager.currentIndex);            _model.dispatch(PluginEventType.PLUGIN_EVENT, "onStreamSwitch", currentItem());        }        [External]        public function currentItem():BitrateItem {            return BitrateItem(streamSelector.streamItems[_switchManager ? _switchManager.currentIndex : streamSelector.currentIndex]);        }        protected function getClipUrl(clip:Clip, mappedBitrate:BitrateItem):String {            log.info("Resolved stream url: " + mappedBitrate.url);            return mappedBitrate.url;            //return (clip.baseUrl ? URLUtil.completeURL(clip.baseUrl, mappedBitrate.url) : mappedBitrate.url);        }        private function checkCurrentClip():Boolean {            var clip:Clip = _player.playlist.current;            if (_clip == clip) return true;            if (clip.urlResolvers && clip.urlResolvers.indexOf(_model.name) < 0) {                return false;            }            _clip = clip;            return true;        }        [External]        public function checkBandwidth():void {            log.debug("checkBandwidth");            if (! checkCurrentClip()) return;            _start = _provider ? _provider.time : 0;            _hasDetectedBW = false;            _bitrateStorage.clear();            detect();        }        [External]        public function setBitrate(bitrate:Number):void {            log.debug("set bitrate()");            if (! checkCurrentClip()) return;            try {                if (_player.isPlaying() || _player.isPaused()) {                    switchStream(getMappedBitrate(bitrate));                    _config.dynamic = false;                    if (_switchManager) {                        _switchManager.autoSwitch = false;                    }                }            } catch (e:Error) {                log.error("error when switching streams " + e);            }        }        [External]        public function enableDynamic(enabled:Boolean):void {            log.debug("set dynamic(), currently " + _config.dynamic + ", new value " + enabled);            if (_config.dynamic == enabled) return;            _config.dynamic = enabled;            if (enabled) {                if (! _switchManager) {                    var clip:Clip = _player.playlist.current;                    initQoS(clip.getNetStream(), clip);                }                _switchManager.autoSwitch = true;            } else {                if (_switchManager) {                    _switchManager.autoSwitch = false;                }            }        }        [External]        public function get labels():Object {            if (! bitrateItems) {                buildBitrateList(_player.playlist.current);            }            var labels:Object = {};            for (var i:int = 0; i < bitrateItems.length; i++) {                var item:BitrateItem = bitrateItems[i] as BitrateItem;                if (item.label) {                    labels[item.bitrate] = item.label;                }            }            return labels;        }        /**         * Gets the current bitrate. The returned value is the bitrate in use after the latest bitrate transition has been completed. If         * a transition is in progress the value reflects the bitrate right now being used, not the one we are changing to.         * @return         */        [External]        public function get bitrate():Number {            log.debug("get bitrate()");            if (! checkCurrentClip()) return undefined;            if (_config.rememberBitrate && _bitrateStorage.bandwidth >= 0) {                log.debug("get bitrate(), returning remembered bandwidth");                var mappedBitrate:BitrateItem = getMappedBitrate(_bitrateStorage.bandwidth);                return mappedBitrate.bitrate;            }            log.debug("get bitrate(), returning current bitrate");            return currentItem().bitrate;        }        public function getDefaultConfig():Object {            return null;        }        private function get streamSelector():StreamSelector {            if (! _streamSelector) {                buildBitrateList(_player.playlist.current);            }            return _streamSelector;        }    }}