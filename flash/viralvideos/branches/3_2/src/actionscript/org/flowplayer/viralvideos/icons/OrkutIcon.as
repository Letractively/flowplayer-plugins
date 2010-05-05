/*
 *    Author: Anssi Piirainen, <api@iki.fi>
 *
 *    Copyright (c) 2009 Flowplayer Oy
 *
 *    This file is part of Flowplayer.
 *
 *    Flowplayer is licensed under the GPL v3 license with an
 *    Additional Term, see http://flowplayer.org/license_gpl.html
 */
package org.flowplayer.viralvideos.icons {
    import flash.display.DisplayObjectContainer;

    import org.flowplayer.ui.AbstractButton;
    import org.flowplayer.ui.ButtonConfig;
    import org.flowplayer.view.AnimationEngine;
    import org.flowplayer.viral.assets.OrkutIcon;

    public class OrkutIcon extends AbstractIcon {

        public function OrkutIcon(config:ButtonConfig, animationEngine:AnimationEngine) {
            super(config, animationEngine, "Orkut");
        }

        override protected function createIcon():DisplayObjectContainer {
            return new org.flowplayer.viral.assets.OrkutIcon();
        }
    }
}