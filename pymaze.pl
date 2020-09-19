#!/usr/bin/python3
#
#   Copyright 2020 Thierry Escande
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

import random
import gi
import cairo
import math

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
from gi.repository import Gdk

num_cols = 81
num_rows = 81

def show_maze(maze):
	for row in maze:
		for v in row:
			print(" " if v else "X", end = ' ')
		print("")
	print("")

def init_maze(maze):
	maze.clear()

	for r in range(num_rows):
		row = []
		for c in range(num_cols):
			row.append(1 if r % 2 and c % 2 else 0)
		maze.append(row)

def create_maze(maze):
	stack = []
	neighbours = [ [ -2, 0 ], [ 0, 2 ], [ 2, 0 ], [ 0, -2 ] ]
	walls = [ [ -1, 0 ], [ 0, 1 ], [ 1, 0 ], [ 0, -1 ] ]

	row = random.randrange(1, num_rows, 2);
	col = random.randrange(1, num_cols, 2);
	maze[row][col] = 2

	stack.append([row, col])

	while (len(stack)):
		cell = stack.pop(-1)
		row = cell[0]
		col = cell[1]

		# Choose a neighbour
		r = random.randint(0, 3)
		for i in range(4):
			n = neighbours[(i + r) % 4]
			n_row = row + n[0]
			n_col = col + n[1]

			if n_row < 0 or n_row >= num_rows or n_col < 0 or n_col >= num_cols:
				continue

			if maze[n_row][n_col] == 2:
				continue

			stack.append([row, col])

			maze[n_row][n_col] = 2
			stack.append([n_row, n_col])

			# Remove wall between cells
			w = walls[(i + r) % 4]
			maze[row + w[0]][col + w[1]] = 2

			break

	for row in range(num_rows):
		if maze[row][1]:
			maze[row][0] = 2
			break

	for row in range(num_rows - 1, 0, -1):
		if maze[row][num_cols - 2]:
			maze[row][num_cols - 1] = 2
			break

def on_draw(win, cr, maze):
	cr.set_source_rgb(0, 0, 0)

	for row in range(num_rows):
		for col in range(num_cols):
			if maze[row][col] == 0:
				cr.rectangle(col * 10 + 10, row * 10 + 10, 10, 10)
				cr.fill()

def on_key_press(win, event, maze):
	if event.keyval == Gdk.KEY_F5:
		init_maze(maze)
		create_maze(maze)
		win.queue_draw()

def gui(maze):
	win = Gtk.Window()
	win.set_default_size(num_cols * 10 + 20, num_rows * 10 + 20)
	da = Gtk.DrawingArea()
	win.add(da)

	win.connect("destroy", Gtk.main_quit)
	win.connect("key_press_event", on_key_press, maze)
	da.connect('draw', on_draw, maze)

	win.show_all()
	Gtk.main()

def main():
	maze = []

	init_maze(maze)
	create_maze(maze)
	#show_maze(maze)
	gui(maze)


if __name__ == "__main__":
	main()

