#!/usr/bin/python

from random import randint
import os
import time


def right():
  print 'RIGHT!'

def wrong(answer):
  print "WRONG, it's {0}".format(answer)

while True:
  os.system('clear')

  a = randint(0,9)
  b = randint(0,9)
  
  answer = str(a + b)
  input = str(raw_input('\nWhat is {0} + {1}? '.format(a,b)))

  if input.lower() == 'q':
    print 'kthxbai'
    exit(0)
  
  right() if input == answer else wrong(answer)
  time.sleep(2)
  
