# Sobel-Edge-Detection-FPGA
Sobel Edge Detection on Spartan 3E board usign Xilinx ISE. The input image is hardcoded and contains colour pixels despite the video output being black and white.
The module displays the B&W input image and hte sobel edge detection results side by side on button presses.
Input image generated through IP generation. 


## Results:
![results](https://github.com/AEmreEser/Sobel-Edge-Detection-FPGA/blob/main/sobel_results.jpg)


### Important:
files lena_input.ngc and lena_input.mif must be copied into the project folder (xilinx ISE) for the precompiled modules to be used. 


##### Detailed info regarding the Sobel edge detection algorithm could be found here: https://homepages.inf.ed.ac.uk/rbf/HIPR2/sobel.htm
