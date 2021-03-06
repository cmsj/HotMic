//
//  THMLogging.h
//  HotMic
//
//  Created by Chris Jones on 04/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#ifndef THMLogging_h
#define THMLogging_h

#define checkErr( err) \
if(err) {\
OSStatus error = static_cast<OSStatus>(err);\
fprintf(stdout, "CAPlayThrough Error: %ld ->  %s:  %d\n",  (long)error,\
__FILE__, \
__LINE__\
);\
fflush(stdout);\
}

#define checkErrBool(err) \
if (err != noErr) { \
NSLog(@"%s:%d: OSError: %d", __FILE__, __LINE__, err); \
return NO; \
}

#endif /* THMLogging_h */
