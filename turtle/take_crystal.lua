
turtle.dig()
turtle.forward()
while turtle.detectUp() do
	turtle.digUp()
	turtle.up()
end
turtle.up()
while not turtle.detect() do
	turtle.forward()
end
turtle.up()
turtle.down()
while turtle.detectDown() do
	turtle.back()
end
while not turtle.detectDown() do
	turtle.down()
end
turtle.back()
