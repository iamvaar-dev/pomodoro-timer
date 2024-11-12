enum TimerState { initial, running, paused, finished }
enum TimerType { focus, shortBreak, longBreak }

class TimerProvider {
  TimerState state = TimerState.initial;
  TimerType type = TimerType.focus;
  int duration = 0;
  
  void updateState(TimerState newState) {
    state = newState;
  }
  
  void updateType(TimerType newType) {
    type = newType;
  }
  
  void updateDuration(int newDuration) {
    duration = newDuration;
  }
}
