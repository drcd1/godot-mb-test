# Godot Motion Blur Testbed

This project provides a custom script to compare a motion blur implementation with a ground truth. Check the AnimManager node for the configuration. Play the scene test2.tscn to record the images.


## Parameters
- Record Specific: records the motion blur images at frame at time "next", where the previous frame was at time "prev". If this is disabled, the animation will play normally and nothing will be recorded.
- Prev: timestamp of the frame before the one being recorded
- Next: timestamp of the recorded frame
- Steps: number of samples to compute the ground truth. Higher is better, but expensive.
- Env: the worldenvironment with the motion blur effect. *IT ASSUMES THE MOTION BLUR IS THE FIRST EFFECT IN THE COMPOSITOR*
- Output file: filename of the output image
- Ground Truth file: filename of the ground truth image
- Shutter Open: Vector2(min,max) -  Window of time during which the shutter is open. 0 is previous frame. 1 is current frame. 2 is next frame. If using a centered blur, set time to (0.5,1.5) to have the same result in the ground truth.
- Exposure curve: allows different times to be exposed differently in the ground truth. The default is uniform exposure.


## Warnings
The script has a few hardcoded variables:
- We assume
- line 16: assumes the renderer is rendering to an object with path "../SubViewport"
- line 21: assumes the animated scene is called "mbtest" and has an "AnimationPlayer" node.
- line 22: assumes the animation to be played is called "Animation"

In addition, make sure the Camera3D in viewport has as target the animated camera object in the animated scene (initially I couldn't export the camera animation, so this ended up being setup like this)

