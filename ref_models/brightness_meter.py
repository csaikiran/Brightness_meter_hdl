from PIL import Image
import os
import random
import sys


def calc(pix):
	# our substraction operation from VHDL
    tmp = pix - offset
	# calculation of bram address
	# height >> 1 - divide image height by 2
	# i - (height >> 1) - get senter of image by axix Y
	# (i - (height >> 1)) >> 6 - shift by 6 bith on right for select MSB bits
	# (j - (width >> 1)) >> 6 - same as for Y
	# ((j - (width >> 1)) >> 6) & 0x3F - select only high 6 bits of H_CENTER
	# ((i - (height >> 1)) >> 6) * hsize - shift V_CENTER by 6 bits left
    coef_idx = (((i - (height >> 1)) >> 6) * hsize) | (((j - (width >> 1)) >> 6) & 0x3F)
    # multiplication pixel by weight
    tmp = tmp * coeff[coef_idx]
    return tmp

# create a array for pixels
pixels = list()
# set width and height of image
height = 2048
width = 2448

# set a offset value
offset = 0b000000010100
#create a array for coefficients (like a bram)
coeff = list()
hsize = 2**6
vsize = 2**5
# loop for generate coefficients
for i in range(hsize * vsize):
	# check if we have go to - values when calc. this logic for imitate VHDL code
	# in VHDL code we generate binary number 8 bits width. and when we do a multiplication we convert a weight to a signed
	# so with this condition we create a signed numbers
    if ((i & 0xFF) > 127):
        tmp = -128 + (i & 0x7F)  ## why only this 0x7F ?
        coeff.append(tmp)
	# in another case we do not anything
    else:
		# we need add & 0xFF for get 8 bit width digits.
		# & - logic AND operation
        coeff.append(i & 0xFF)

#loop for generate image
for i in range(height):
	# add ne line into image
    pixels.append([])
    for j in range(width >> 1):  # width >> 1 because we have 2 pixels per clock
		#add nwe pixel into current line of image
        pixels[i].append((i + j) & 0xFFF)
        pixels[i].append((i + j) & 0xFFF)

# main algorithm
deviation = 0
for i in range(height):
    for j in range(width):
        deviation += calc(pixels[i][j])   # Accumulator logic "+=" means i = i+1
		


shift = 12
deviation = deviation >> shift
# prion operation on a display
print("deviation : " + str(deviation))
