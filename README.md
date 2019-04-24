# HotMic

## What is it?
This app is intended to be a functional Play Through app for macOS.

## What does that mean?
What is a Play Through app? It means it takes input sound from one audio device and plays it through the output of another device. A good example would be using a Line In on a USB soundcard and being able to hear it through your normal Mac speakers.

## Does it work?
Not yet, but it could, and you could help!

## Why doesn't it work?
Apple provides some (very old) sample code for how to do this, in a project called CAPlayThrough, and it sort-of works, but over time the two devices lose synchronisation and the audio plays later and later until it is so late that Core Audio discards it. This seems to be a fundamental flaw in the VariSpeed Audio Unit and appears uncorrectable.

## Are you sure this is possible?
Yes, the fine folk over at Rogue Amoeba have been able to produce three perfectly stable apps that offer a Play Through feature, at one time or another (LineIn, SoundSource (prior to v4) and Audio Hijack). Others have tried, but I'm not aware of any that have succeded, likely because most seem to have started from CAPlayThrough, as I did.

## So how should this be fixed?
From what I've been able to learn by reading old posts on Apple's coreaudio-api mailing list, at least one person wrote their own Audio Unit to replace VariSpeed, but the resource they used to learn how to do that, has long since disappeared from the Internet.

The current best sounding suggestion for how it might be able to work, is by creating an Aggregate audio device that contains the desired input and output audio devices, and joining them together with an AUGraph. This would mean the OS itself would keep the devices in sync. There's a separate branch in this repo which has the beginnings of an implementation of this plan (ie it can create an aggregate device with the relevant subdevices attached), but I don't understand enough about AUGraphs to implement the rest right now.

## Where do we go from here?
I don't currently plan to invest many more hours into this for now. SoundSource 3 will presumably work for some time to come, so I don't *need* HotMic to work until SoundSource is rendered broken by some future OS update.

However, if someone comes across this and knows their way around CoreAudio a bit better than I do, I would love to collaborate with you to get this working. File Issues or Pull Requests and let's talk!

## Whose shoulders did you stand on for this?

A non-exhaustive list:
 * Apple (for the CAPlayThrough example)
 * Various CAPlayThrough forks with fixes/changes:
   * [https://github.com/liscio/CAPlayThrough](https://github.com/liscio/CAPlayThrough)
   * [https://github.com/yujitach/CAPlayThrough](https://github.com/yujitach/CAPlayThrough)
 * Current and historical posters on coreaudio-api@lists.apple.com for their discussions about CAPlayThrough
