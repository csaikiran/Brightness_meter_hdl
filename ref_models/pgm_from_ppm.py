from PIL import Image
import random
import sys

# load a image
img_name = sys.argv[1]
new_img_name = sys.argv[2]
img = Image.open(img_name)
gray_img = Image.new("L", img.size)
gray_img = img.convert("L")
gray_img.save(new_img_name)
