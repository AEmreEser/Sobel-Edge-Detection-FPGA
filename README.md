# Sobel-Edge-Detection-FPGA
Sobel Edge Detection on Spartan 3E board usign Xilinx ISE. The input image is hardcoded and contains colour pixels despite the video output being black and white.
The module displays the B&W input image and hte sobel edge detection results side by side on button presses.
Input image generated through IP generation. 

Specifications:
- Control – Datapath organization
- Area: 130 std cells, avg 14.45 cell pins (SRAM and VGA controller not included)
- Timing: 1 clock cycle per pixel


## Results:
![results](https://github.com/AEmreEser/Sobel-Edge-Detection-FPGA/blob/main/sobel_results.jpg)


### Important:
files lena_input.ngc and lena_input.mif must be copied into the project folder (xilinx ISE) for the precompiled modules to be used. 


##### Detailed info regarding the Sobel edge detection algorithm could be found here: https://homepages.inf.ed.ac.uk/rbf/HIPR2/sobel.htm
