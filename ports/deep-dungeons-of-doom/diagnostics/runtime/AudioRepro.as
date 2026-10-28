package {
    import flash.display.Sprite;
    import flash.media.SoundMixer;
    import flash.media.AudioPlaybackMode;
    public class AudioRepro extends Sprite {
        public function AudioRepro() {
            trace("AUDIO_BEFORE_CATEGORY");
            var mixer:Object = SoundMixer;
            mixer["audioPlaybackMode"] = AudioPlaybackMode.AMBIENT;
            trace("AUDIO_CATEGORY=" + mixer["audioPlaybackMode"]);
            trace("AUDIO_MIXER_STOPALL=" + typeof SoundMixer.stopAll);
            trace("AUDIO_DONE");
        }
    }
}
