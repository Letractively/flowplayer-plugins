/* * This file is part of Flowplayer, http://flowplayer.org * * By: Anssi Piirainen, <support@flowplayer.org> * Copyright (c) 2008, 2009 Flowplayer Oy * H.264 support by: Arjen Wagenaar, <h264@code-shop.com> * Copyright (c) 2009 CodeShop B.V. * * Released under the MIT License: * http://www.opensource.org/licenses/mit-license.php */package org.flowplayer.pseudostreaming {    import flash.utils.getTimer;    import org.flowplayer.model.ClipEvent;import org.flowplayer.controller.NetStreamControllingStreamProvider;import org.flowplayer.model.ClipEventType;import org.flowplayer.model.Plugin;import org.flowplayer.model.PluginModel;import org.flowplayer.util.PropertyBinder;import org.flowplayer.view.Flowplayer;import flash.events.NetStatusEvent;import org.flowplayer.model.Clip;import flash.net.NetStream;import flash.net.NetConnection;	/**     * @author api     */public class PseudoStreamProvider extends NetStreamControllingStreamProvider implements Plugin {    private var _bufferStart:Number;    private var _config:Config;    private var _fileWithKeyframeInfo:String;    private var _serverSeekInProgress:Boolean;    private var _startSeekDone:Boolean;    private var _model:PluginModel;    private var _seekDataStore:DefaultSeekDataStore;    private var _previousClip:Clip;    private var _currentClip:Clip;    private var _byteRangeNetStream:NetStream;    /**     * Called by the player to set my config.     */    override public function onConfig(model:PluginModel):void {        _model = model;        _config = new PropertyBinder(new Config(), null).copyProperties(model.config) as Config;    }    /**     * Called by the player to set the Flowplayer API.     */    override public function onLoad(player:Flowplayer):void {        log.info("onLoad, registering metadata listener");        _model.dispatchOnLoad();    }    override protected function getClipUrl(clip:Clip):String {    	return _config.rangeRequests ? clip.completeUrl : appendQueryString(clip.completeUrl, 0);    }    override protected function doLoad(event:ClipEvent, netStream:NetStream, clip:Clip):void {        log.info("doLoad()");        _bufferStart = clip.currentTime;        _startSeekDone = false;        if (! _seekDataStore || isNewFile(clip)) {             _seekDataStore = new DefaultSeekDataStore();        }        _seekDataStore.reset();        super.doLoad(event, netStream, clip);    }    private function isNewFile(clip:Clip):Boolean {        return clip.url != _fileWithKeyframeInfo;    }    override protected function doSeek(event:ClipEvent, netStream:NetStream, seconds:Number):void {        log.debug("doSeek()");        var target:Number = clip.start + seconds;        if (isInBuffer(target)) {            log.debug("seeking inside buffer, target " + target + " seconds");            netStream.seek(_seekDataStore.inBufferSeekTarget(target));        } else {            serverSeek(netStream, target);        }    }		override protected function doStop(event:ClipEvent, netStream:NetStream, closeStreamAndConnection:Boolean = false):void {		//reset the current clip		_currentClip = null;		log.debug("Clearing clip and stopping ");		super.doStop(event, netStream, closeStreamAndConnection);	}        override protected function doSwitchStream(event:ClipEvent, netStream:NetStream, clip:Clip, netStreamPlayOptions:Object = null):void {    	        log.debug("doSwitchStream()");        clip.currentTime = time;        //if this is the first time switching remove the start time or else it will increase the seeking time        //clip.currentTime = (!_currentClip ? clip.currentTime - clip.start : clip.currentTime);        _bufferStart = clip.currentTime;        _currentClip = clip;        //unbind a previous onmetadata listener        clip.unbind(onMetaData);        clip.onMetaData(switchOnMetaData);        log.debug("Switching stream with current time: " + clip.currentTime);        load(event, clip);        //	    if (!isNewFile(clip)) {//			clip.currentTime = netStream.time;//	    	log.debug("Switching stream with current time: " + clip.currentTime);//	    	serverSeek(netStream, clip.currentTime, true);//	    } else {////			clip.currentTime = netStream.time;//			//if this is the first time switching remove the start time or else it will increase the seeking time//			//clip.currentTime = (!_currentClip ? clip.currentTime - clip.start : clip.currentTime);//			_bufferStart = clip.currentTime;//	    	_currentClip = clip;////			//unbind a previous onmetadata listener//            clip.unbind(onMetaData);//	    	clip.onMetaData(switchOnMetaData);////	    	log.debug("Switching stream with current time: " + clip.currentTime);////	    	load(event, clip);//	    }    }        private function switchOnMetaData(event:ClipEvent):void {        log.debug("switchOnMetaData(), netStream " + netStream);        clip.onMetaData(onMetaData);        clip.unbind(switchOnMetaData);        _startSeekDone = true;        createSeekDataStore(Clip(event.target));		serverSeek(netStream, Clip(event.target).currentTime, true);    }     override public function get bufferStart():Number {        if (! clip) return 0;        return _bufferStart - clip.start;    }    override public function get bufferEnd():Number {        if (! netStream) return 0;        if (! clip) return 0;        //log.error("Bytes Loaded: " + netStream.bytesLoaded + " Bytes Total: " + netStream.bytesTotal + " Buffer: " + netStream.bufferTime + " Buffer Length: " + netStream.bufferLength);        return bufferStart + netStream.bytesLoaded/netStream.bytesTotal * (clip.duration - bufferStart);    }    override protected function getCurrentPlayheadTime(netStream:NetStream):Number {        if (! clip) return 0;        //round the value so playback will end correctly to match the duration        var value:Number = Math.round(_seekDataStore.currentPlayheadTime(netStream.time, clip.start));        return value < 0 ? 0 : value;    }    override public function get allowRandomSeek():Boolean {        if (! _seekDataStore) return false;        return _seekDataStore.allowRandomSeek();    }    private function isInBuffer(seconds:Number):Boolean {        if (!_seekDataStore.dataAvailable) {            log.debug("No keyframe data available, can only seek inside the buffer");            return true;        }                if (_config.rangeRequests) return false;                return bufferStart <= seconds - clip.start && seconds - clip.start <= bufferEnd;    }    private function serverSeek(netStream:NetStream, seconds:Number, setBufferStart:Boolean = true, silent:Boolean = false):void {        log.debug("serverSeek()");        if (setBufferStart) {            _bufferStart = seconds;        }        if (_config.rangeRequests) {        	log.debug("Making range request to server, usin URL " + clip.completeUrl);        	netStream.play(clip.completeUrl , seconds, _seekDataStore);        	return;        }        var requestUrl:String = appendQueryString(clip.completeUrl , seconds);        log.debug("doing server seek, url " + requestUrl);        if (! silent) {            _serverSeekInProgress = true;        }        netStream.play(requestUrl);	}		private function getByteRange(start:Number):Number {		return  _seekDataStore.getQueryStringStartValue(start);	}    private function appendQueryString(url:String, start:Number):String {        log.debug("appendQueryString(), start == " + start);        // http://flowplayer.org/forum/7/48461         if (start == 0) return url;        var query:String = url + (url.indexOf("?") >= 0 ? "&" : "?") +               _config.queryString.replace("${start}", _seekDataStore.getQueryStringStartValue(start));        log.debug("query string is " + query);        return query;    }    override protected function onMetaData(event:ClipEvent):void {        if (_startSeekDone) {            return;        }        log.info("received metaData for clip" + Clip(event.target));        log.debug("clip file is " + clip.url);        if (isNewFile(event.target as Clip)) {            log.info("new file, creating new keyframe store");            createSeekDataStore(Clip(event.target));            clip.dispatch(ClipEventType.START, pauseAfterStart);	        if (pauseAfterStart) {	            clip.dispatch(ClipEventType.PAUSE);	        }	        // at this point we seek to the start position if it's greater than zero	        log.debug("seeking to start, pausing after start: " + pauseAfterStart);	        if (clip.start > 0) {	            serverSeek(netStream, clip.start, true, true);	            _startSeekDone = true;	        } else if (pauseAfterStart) {	            netStream.seek(0);	            pauseAfterStart = false;	        }		}    }    private function createSeekDataStore(clip:Clip):void {        _seekDataStore = DefaultSeekDataStore.create(clip, clip.metaData);        // # 75, events should be dispatched only once        _fileWithKeyframeInfo = clip.url;    }    override protected function canDispatchBegin():Boolean {        if (_serverSeekInProgress) return false;        if (clip.start > 0 && ! _startSeekDone) return false;        return true;    }    override protected function onNetStatus(event:NetStatusEvent):void {        log.info("onNetStatus: " + event.info.code);		// #61, must wait buffer full instead of Play.Start for videos without metadatas.        if (event.info.code == "NetStream.Buffer.Full") {            log.debug("started, will pause after start: " + pauseAfterStart);            // we need to pause here because the stream was started when server-seeking to start pos            if (paused || pauseAfterStart) {                log.info("started: pausing to pos 0 in netStream");                netStream.seek(0);                pause(null);                if (_startSeekDone) {                    pauseAfterStart = false;                }            }            // at this stage the server seek is in target, and we can dispatch the seek event            if (_serverSeekInProgress) {                _serverSeekInProgress = false;                clip.dispatch(ClipEventType.SEEK, seekTarget);            }        } else if (event.info.code == "NetStream.Play.Stop") {        	log.debug(netStream.time.toString());        }    }    public function getDefaultConfig():Object {        return null;    }        override public function get type():String {		return "pseudo";		}		override protected function createNetStream(connection:NetConnection):NetStream {				if (_config.rangeRequests) {            log.debug("Using ByteRangeNetStream");			import org.flowplayer.pseudostreaming.net.ByteRangeNetStream;			//_byteRangeNetStream = new ByteRangeNetStream(_connection);			return 	new ByteRangeNetStream(connection);		}		return null;    }}}