local l3d = require("love3d")
l3d.import(true)

local cpml = require "cpml"

local camx = 0
local camy = 0.1
local camz = 0

local camlookx = 0
local camlooky = 0
local camlookz = 0

local camrot = cpml.vec3()
local sensitivity = 15

local chunks = {}
local chunkmeshes = {}

local pointlights = {{{-2,1,8},0.2,0.09, 0.032,{0.05,0.05,0.05},{0.8,0.8,0.8},3.0},{{2,1,8},0.2,0.09, 0.032,{0.05,0.05,0.05},{0.8,0.8,0.8},3.0}}

local show_debug = true

local debug_text = "Program started...\n"

local shader = 0

local vox_verts =  {{-1,-1,-1},
					{ 1,-1,-1},
					{ 1,-1, 1},
					{-1,-1, 1},
					{-1, 1,-1},
					{ 1, 1,-1},
					{ 1, 1, 1},
					{-1, 1, 1}}

function getVerts(x,y,z)
	local verts = {}
	
	for _,vert in ipairs(vox_verts) do
		table.insert(verts,cpml.vec3(vert[1]+x,vert[2]+y,vert[3]+z))
	end
	
	return verts
end

function generateChunks()
	local c = {}
	
	for cx=1,16 do
		table.insert(c,{})
		for cy=1,16 do
			local chunk = {}
			for x=1,16 do
				table.insert(chunk,{})
				for y=1,16 do
					table.insert(chunk[x],{})
					for z=1,16 do
						table.insert(chunk[x][y],1)
					end
				end
			end
			table.insert(c[cx],chunk)
		end
	end
	
	return c
end

function generateChunkMeshes(c)
	local meshdata = {}
	
	for cx=1,#c do
		for cy=1,#c[cx] do
			local chunk = c[cx][cy]
			for x=1,#chunk do
				for y=1,#chunk[x] do
					for z=1,#chunk[x][y] do
						if chunk[x][y][z] > 0 then
							table.insert(meshdata,{getVerts(x,y,z),cx,cy})
						end
					end
				end
			end
		end
	end
	
	for _,data in ipairs(meshdata) do
		meshdata[_][1] = l3d.new_triangles(data[1])
	end
	
	return meshdata
end

function love.load()
	debug_text = debug_text .. "Generating chunks...\n"
	chunks = generateChunks()
	debug_text = debug_text .. "Generating chunkmeshes...\n"
	chunkmeshes = generateChunkMeshes(chunks)
	
	debug_text = debug_text .. "Setting culling to 'back'\n"
	l3d.set_culling("back")
	
	debug_text = debug_text .. "Compiling shader...\n"
	shader = love.graphics.newShader("shaders/shader.txt")
end

function love.update(dt)
	local mousex, mousey = love.mouse.getPosition()
	mx = mousex - love.graphics.getWidth()/2
	my = mousey - love.graphics.getHeight()/2
	camrot.x = camrot.x + math.rad(my * sensitivity * dt)
	camrot.y = camrot.y + math.rad(mx * sensitivity * dt)
	love.mouse.setPosition(love.graphics.getWidth()/2,love.graphics.getHeight()/2)
	if love.keyboard.isDown('j') then
		camrot.y = camrot.y - dt
		--l3d.rotate(-0.2,cpml.vec3(0,0,1))
		-- camroty = camroty - 0.01
	end
	if love.keyboard.isDown('l') then
		camrot.y = camrot.y + dt
		--l3d.rotate(0.2,cpml.vec3(0,0,1))
		-- camroty = camroty + 0.01
	end
	if love.keyboard.isDown('e') then
		camy = camy + dt
		-- camlooky = camlooky+0.01
		--view:translate(view,cpml.vec3(camx,camy,camz))
	end
	if love.keyboard.isDown('q') then
		camy = camy - dt
		-- camlooky = camlooky-0.01
		--view:translate(view,cpml.vec3(camx,camy,camz))
	end
	if love.keyboard.isDown('w') then
		camx = camx-math.sin(camrot.y)*dt
		camy = camy-math.cos(-camrot.y)*dt
		camz = camz-math.cos(camrot.x)*dt
	end
	if love.keyboard.isDown('s') then
		camx = camx+math.sin(camrot.y)*dt
		camy = camy+math.cos(-camrot.y)*dt
		camz = camz+math.cos(camrot.x)*dt
	end
	if love.keyboard.isDown('d') then
		camx = camx-math.cos(camrot.y)*dt
		camy = camy-math.sin(-camrot.y)*dt
		camz = camz-math.sin(camrot.z)*dt
	end
	if love.keyboard.isDown('a') then
		camx = camx+math.cos(camrot.y)*dt
		camy = camy+math.sin(-camrot.y)*dt
		camz = camz+math.sin(camrot.z)*dt
	end
end

function love.draw()
	l3d.set_depth_test("less")
	l3d.set_depth_write(true)
	l3d.clear(true)
	love.graphics.setBackgroundColor(40,60,240)
	love.graphics.setShader(shader)
	
	local v = cpml.mat4()
	v:rotate(v, -math.pi, cpml.vec3.unit_x)
	v:rotate(v, camrot.x, cpml.vec3.unit_x)
	v:rotate(v, camrot.y, cpml.vec3.unit_z)
	v:translate(v, cpml.vec3(camx,camy,camz))
	
	local w, h = love.graphics.getDimensions()

	local proj = cpml.mat4.from_perspective(60, w/h, 0.1, 1000.0)
	local model = cpml.mat4()
	
	for _,p in ipairs(pointlights) do
		local n = _-1
		shader:send("pointlights["..tostring(n).."].position",p[1])
		shader:send("pointlights["..tostring(n).."].constant",p[2])
		shader:send("pointlights["..tostring(n).."].linear",p[3])
		shader:send("pointlights["..tostring(n).."].quadratic",p[4])
		shader:send("pointlights["..tostring(n).."].ambient",p[5])
		shader:send("pointlights["..tostring(n).."].diffuse",p[6])
		shader:send("pointlights["..tostring(n).."].intensity",p[7])
	end
	
	shader:send("maxpointlights",1)
	
	shader:send("u_light_direction", lightDir)
	shader:send("u_projection", proj:to_vec4s())
	shader:send("u_view", v:to_vec4s())
	
	for _,d in ipairs(chunkmeshes) do
		model:identity()
		model:translate(model, cpml.vec3(d[2],d[3],0))
		
		shader:send("u_model",model:to_vec4s())
		
		love.graphics.draw(d[1].mesh)
	end
	
	love.graphics.setShader()
	l3d.set_depth_test()
	l3d.set_depth_write(false)
	
	love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
	love.graphics.print("Current MS:  "..tostring(math.floor(love.timer.getDelta( )*1000*100)/100), 10, 30)
end
