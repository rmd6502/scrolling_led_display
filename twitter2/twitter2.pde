import processing.serial.*;

Serial serialPort;
Twitter myTwitter;

static final int ADVANCEBY = 1;                   // number of cols to advance by per shift
static final int REQUESTDELAY = 0;                // delay between twitter queries after msg scrolls (sec)
static final int NUMRESPONSES = 1;                // just get latest tweet 
static final int SMALLDELAY = 45;                 // delay for small messages (msec)
static final int LARGEDELAY = 600;               // delay for large messages (msec)
static final String SEARCHFOR = "alphaonelabs";   // any tweet containing this string
static final String ERRMSG = "TWITTER BROKEN!\n"; // display when twitter b0rks

String lastTweet = ""; // use to determine if tweet has changed
String latestTweet = "";


void setup() {
  serialPort = new Serial(this, Serial.list()[1], 115200);
  myTwitter = new Twitter(); // anon access    
};


void draw() {

  String scrollMsg;
 
  scrollMsg = fetchLatestTweet(); 
  serialInit();
  scroll(scrollMsg, true);
      
  delay(REQUESTDELAY * 1000); // secs between queries

};


String fetchLatestTweet() {
  
  String scrollMsg = "";
  
  try {
  
    Query query = new Query(SEARCHFOR);
    query.setRpp(NUMRESPONSES);
    QueryResult result = myTwitter.search(query);
    
    ArrayList tweets = (ArrayList) result.getTweets();


    serialInit(); // clear the screen and set margin

    for (int i = 0; i < tweets.size(); i++) 
    {                   
      Tweet t = (Tweet) tweets.get(i);
      String user = t.getFromUser();
      latestTweet = t.getText();
      Date d = t.getCreatedAt();
      println("Tweet by " + user + " at " + d + ": " + latestTweet);
      
      //println("lastTweet: " + lastTweet + " latestTweet: " + latestTweet + "\n");
      
      scrollMsg = user + ": " + latestTweet + "\n";   

//      if (! latestTweet.equals(lastTweet))
//        scrollMsg = "[BREAKING] " + scrollMsg; // indicate a new tweet
//      
      lastTweet = latestTweet; // keep track
    };

  }
  catch (TwitterException te) {
    String errorMsg = "Can't connect to twitter: " + te + "\n";
    print(errorMsg);
    scroll(ERRMSG, false);
  };
  
  return scrollMsg;
}


void serialInit() {
  
  serialPort.clear();
  delay(250);
  serialPort.write("c\n");
  delay(100);
  serialPort.write("m0\n");
  delay(100);
  serialPort.write("p0\n");
  delay(100);
}


void scroll(String s, Boolean flushLeft) {
  
  int slen = s.length();
  println("slen: " + slen);
  String[] schars = s.split("");
  int pos = 100;
  
  String cleanString = "";
  for (int i=0; i < schars.length; i++) // skip any non-ascii characters
  {
    //print("i: " + i + " ");
    String currChar = schars[i];
    byte[] charBytes = currChar.getBytes();
    if ((charBytes.length==1) && (charBytes[0] >= 32) && (charBytes[0] <= 127)) 
        cleanString += (char)charBytes[0];
  }  
  
  // set the position and write the strings. we need a long delay here so the 
  //   arduino has time to retrieve the serial write.
  serialPort.write("p" + pos + "\n");
  delay(SMALLDELAY);
  
  int numSections = ceil((float)cleanString.length()/50);
  
  for (int i=0; i < numSections; i++) 
  {
    int startPos = i*50;
    int endPos = startPos + 50;
    if (endPos > cleanString.length())
      endPos = cleanString.length();
      
    println("numSections: " + numSections + ", startPos: " + startPos + ", endPos: " + endPos);
    String cleanStringSection = cleanString.substring(startPos, endPos);
    serialPort.write("s" + cleanStringSection + "\n"); 
    delay(LARGEDELAY);   
  }
 
  int messageLen = 6*cleanString.length() + 6; // add 1 char 
  
  if (flushLeft)
    messageLen += 100; // flush the screen all the way left if desired
  
  for (int i=0; i < messageLen/ADVANCEBY; i++) 
  { // move the chars left one vertical column at a time
    serialPort.write("l" + ADVANCEBY + "\n");
    delay(SMALLDELAY);
  }

}
