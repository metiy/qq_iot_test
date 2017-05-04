TARGETS := demo
OBJS	:= main.o
CROSS   := 

INCLUDE += -I /home/pi/Tencent_iot_SDK/include/

CFLAGS  +=  $(INCLUDE)

LIB     += -L/home/pi/Tencent_iot_SDK/lib 
LIB     += -ltxdevicesdk -lhiredis 


.PHONY: all

all:$(TARGETS)

$(TARGETS) : $(OBJS)
	$(CC) -o $(TARGETS) $(OBJS) $(LIB)



.PHONY:clean
clean:
	rm -rf $(TARGETS) $(OBJS)

