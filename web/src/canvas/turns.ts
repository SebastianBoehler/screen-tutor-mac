/** Track both speakers: an interrupted tutor becoming quiet does not end the learner's turn. */
export class SpeechTurns {
  private learner = false;
  private tutor = false;
  constructor(private changed: (speaking: boolean) => void) {}
  event(type: string) {
    if (type === 'input_audio_buffer.speech_started') this.learner = true;
    else if (type === 'input_audio_buffer.speech_stopped') this.learner = false;
    else if (type === 'output_audio_buffer.started') this.tutor = true;
    else if (type === 'output_audio_buffer.stopped' || type === 'output_audio_buffer.cleared')
      this.tutor = false;
    else return;
    this.changed(this.learner || this.tutor);
  }
  reset() {
    this.learner = false;
    this.tutor = false;
    this.changed(false);
  }
}
