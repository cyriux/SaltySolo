/*
 * EasyTheremin
 * Cyrille Martraire 2009
 * 
 * Reads 2 analog inputs (LDR sensing ordinary light) and 2 digital inputs (switches)
 * Sends MIDI notes, pitch bend and continuous controller 1 (mod wheel)
 * 
 * 
 */

//i/o settings
#define ledPin 13   // select the pin for the LED
#define noteOnSwitch 10
#define noteOn2Switch 11
#define pitchAnalog 0
#define expressionAnalog 1


//MIDI settings
int velocity = 127;
int scale[] = {48, 51, 53, 55, 58, 60, 63, 65, 67, 70, 72}; //C, D#, F, G, A# : 3 and 4
int scaleLen = 11;
int noteChannel = 0x90;// noteOn | channel 0
int pitchBendChannel = 0xe0; //0xe0 | channel
int ccChannel = 0xb0; // 0xb0 | channel

// current state
int count = 0;//loop count
int pitchReading = -1;
int playMode = -1;
int pitch = 0;
int note = 0;
int switchState = 1;
int switch2State = 1;
int expressionReading = -1;
byte expression = 0;

byte pb_lsb = 0;
byte pb_msb = 0;
int deltaPitch = 0;

// last state
int lastPitch = -1;
int lastNote = -1;
int lastExpression = -1;



void setup() {
  pinMode(ledPin, OUTPUT);  // declare the ledPin as an OUTPUT
  
  //  Set MIDI baud rate:
  Serial.begin(31250);
  //Serial.begin(19200);
  //Serial.print("Starting");
}

void loop() {
  count = count + 1;
  if (count == 10){
     count = 0;
  }
  
  switchState = digitalRead(noteOnSwitch);
  switch2State = digitalRead(noteOn2Switch);
  playMode = processPlayMode();
  
  if (playMode != -1){
    pitchReading = analogRead(pitchAnalog);
    //Serial.print("pitc = ");
    //Serial.println(pitchReading);
    
    note = selectNote();
     
    // new note
    if (lastNote == 1) {
       startNote();
    } else {
       // continuing note
      
       // another button has been pressed since last time
       if (lastNote != note){
          stopNote();
          startNote();
          
          //this if() is also responsible for the gliding between notes; to prevent it, need to compare to last switches combination instead of the last note
       } else {
           // check for pitch bend
           deltaPitch = pitchReading - lastPitch;
           
           // Process only 1/10 times to reduce bandwidth of cc messages
           if (count == 0 && deltaPitch > 5 || -deltaPitch > 5){
             // do pitch bend, range is 0-16384, center at 0x40 0x00
             pitch = pitchReading /4;
             pb_lsb = pitch & 0x7F;
             pb_msb = pitch >> 7;
             
             //pitch bend is kind random here (did not finish the job, and already happy with the result)
             // because of the previous if() pitch bend is only active on the highest note
             noteOn(pitchBendChannel, pb_lsb - 0x40, pitch);
           }
       }
    }
  } else {
    stopNote();
  }
 
  int expressionReading = analogRead(expressionAnalog);
    //Serial.print("expr = ");
    //Serial.println(reading);
  expression = expressionReading / 4;
  expression = expression;
  // Process only 1/10 times to reduce bandwidth of cc messages
  if (count == 0 && expression != lastExpression){
     noteOn(ccChannel, 1, expression);
  }
  lastExpression = expressionReading;
      
  delay(10);
}

int processPlayMode(){
  if(switch2State == 0){
       if(switchState == 0){
         //both buttons pressed => jump two notes higher in the scale
        return 2;
       } else {
         //only button 2 pressed => jump one note higher in the scale
         return 1;
       }
   }
   if (switchState == 0){
        //only button 1 pressed => stay at note in the scale
        return 0;
   } else {
        //no button pressed => do not play
        return -1;
   }
}

//  plays a MIDI note.  Doesn't check to see that
//  cmd is greater than 127, or that data values are  less than 127:
int selectNote() {
     // select note to play
     pitch = pitchReading / 30;//half range
     
     // jump to higher note according to the play mode
     pitch = pitch + playMode;
     
     // make sure no index is out of bounds
      if (pitch > scaleLen -1){
       pitch = scaleLen -1;// note in scale if only button one pressed
     }
     
     return scale[pitch];
}

//new note
void startNote() {
  noteOn(noteChannel, note, velocity);
  lastNote = note;
  lastPitch = pitchReading;
}

//stop last MIDI note sent (if there was one) and reset pitch bend.
void stopNote() {
  if (lastNote > 0) {
      //note off
      noteOn(noteChannel, lastNote, 0x00);
      
      //reset pitch bend to center
      noteOn(pitchBendChannel, 0x40, 0x00);
      
      //reset last state
      lastNote = -1;
      lastPitch = -1;
    }
}

//  plays a MIDI note.  Doesn't check to see that
//  cmd is greater than 127, or that data values are  less than 127:
void noteOn(char cmd, char data1, char data2) {
  Serial.print(cmd, BYTE);
  Serial.print(data1, BYTE);
  Serial.print(data2, BYTE);
}
