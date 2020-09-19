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
import argparse
import bisect
import threading
import time

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
from gi.repository import Gdk
from gi.repository import GLib

class Cell:
	def __init__(self, row, col, parent = None):
		self.row = row
		self.col = col
		self.value = 0
		self.path = False
		self.color = None
		self.heuristic = 0
		self.parent = parent

	# Compare cells
	def __eq__(self, cell):
		return self.row == cell.row and self.col == cell.col

	# Sort cells
	def __lt__(self, cell):
		return self.heuristic < cell.heuristic

	# Print cell
	def __repr__(self):
		return ('(row={0}, col={1}, h={2})'.format(self.row, self.col, self.heuristic))

class Maze:
	def __init__(self, num_rows = 21, num_cols = 21, difficult = False):
		# Row and col numbers must be odd
		self.num_rows = num_rows + 1 if not num_rows & 0x1 else num_rows
		self.num_cols = num_cols + 1 if not num_cols & 0x1 else num_cols
		self.difficult = difficult

		self.board = []
		self.created = False
		self.start_cell = None
		self.end_cell = None

	def is_wall(self, row, col):
		return self.board[row][col].value == 0

	def create(self):
		stack = []
		neighbours = [ Cell(-2, 0), Cell(0, 2), Cell(2, 0), Cell(0, -2) ]
		walls = [ Cell(-1, 0), Cell(0, 1), Cell(1, 0), Cell(0, -1) ]

		self.created = True
		self.board.clear()

		for r in range(self.num_rows):
			row = []
			for c in range(self.num_cols):
				cell = Cell(r, c)
				cell.value = 1 if r & 1 and c & 1 else 0
				row.append(cell)
			self.board.append(row)

		# Choose a first cell randomly
		row = random.randrange(1, self.num_rows, 2);
		col = random.randrange(1, self.num_cols, 2);
		self.board[row][col].value = 2

		stack.append(self.board[row][col])

		while (len(stack)):
			cell = stack.pop(-1)
			row = cell.row
			col = cell.col

			# Choose a random neighbour
			r = random.randint(0, 3)
			for i in range(4):
				n = neighbours[(i + r) % 4]
				n_row = cell.row + n.row
				n_col = col + n.col

				if n_row < 0 or n_row >= self.num_rows or n_col < 0 or n_col >= self.num_cols:
					continue

				n_cell = self.board[n_row][n_col]

				if n_cell.value == 2:
					continue

				# Put the current cell back into the stack
				stack.append(cell)

				# Mark the neighbour as visited and put it
				# into the stack so it's the next cell to be
				# investigated
				n_cell.value = 2
				stack.append(n_cell)

				# Remove wall between cells
				w = walls[(i + r) % 4]
				self.board[row + w.row][col + w.col].value = 2

				break

			# Mark the cell as visited
			cell.value = 2

		self.start_cell = self.board[1][0]
		self.end_cell = self.board[self.num_rows - 2][self.num_cols - 1]
		self.start_cell.value = 2
		self.end_cell.value = 2

		if not self.difficult:
			return

		# Break some walls for a bit more complex maze
		for i in range(max(self.num_rows, self.num_cols)):
			while True:
				row = random.randrange(1, self.num_rows - 1)
				col = random.randrange(1, self.num_cols - 1)

				if self.is_wall(row, col):
					w = 0
					if self.is_wall(row - 1, col):
						w += 1
					if self.is_wall(row + 1, col):
						w += 1
					# 1 wall up or down means we're on a
					# wall end or at the top of a T. We need
					# to choose another wall
					if w == 1:
						continue

					if self.is_wall(row, col - 1):
						w += 1
					if self.is_wall(row, col + 1):
						w += 1

					# We're surounded by 2 walls verticaly
					# or horizontaly. It's a match
					if w == 2:
						break

			self.board[row][col].value = 2

	def distance_to_end(self, cell):
		return (abs(cell.row - self.end_cell.row) +
			abs(cell.col - self.end_cell.col))

	def solve(self, delay = 0):
		neighbours = [ Cell(-1, 0), Cell(0, 1), Cell(1, 0), Cell(0, -1) ]
		open = []
		closed = []

		if not self.created:
			self.create()

		cell = Cell(self.start_cell.row, self.start_cell.col)
		cell.value = 0
		cell.heuristic = self.distance_to_end(cell)

		open.append(cell)

		while len(open):
			if delay:
				time.sleep(delay)

			cell = open.pop(0)
			closed.append(cell)
			self.board[cell.row][cell.col].color = [ 0.8, 0.8, 0.8 ]

			if cell == self.end_cell:
				while cell.parent is not None:
					self.board[cell.row][cell.col].path = True
					cell = cell.parent
				self.board[cell.row][cell.col].path = True
				return

			for i in range(4):
				n = neighbours[i]
				n_row = cell.row + n.row
				n_col = cell.col + n.col

				if (n_row < 0 or n_row >= self.num_rows or
				    n_col < 0 or n_col >= self.num_cols):
					continue

				# This is a wall
				if self.board[n_row][n_col].value == 0:
					continue

				n_cell = Cell(n_row, n_col, cell)
				if n_cell in closed:
					continue

				# Generate heuristics
				n_cell.value = cell.value + 1
				n_cell.heuristic = (n_cell.value +
						    self.distance_to_end(cell))

				# Lookup in open for same cell with a lower value
				if not self.lookup_cell_low_value(open, n_cell):
					self.board[n_cell.row][n_cell.col].color = [ 0.5, 0.5, 0.5 ]
					bisect.insort_left(open, n_cell)

		print("No path found!!!")

	def lookup_cell_low_value(self, open, cell):
		for c in open:
			if c == cell and c.value < cell.value:
				return True
		return False

	def show_maze(self):
		for row in self.maze:
			for v in row:
				print(" " if v else "X", end = ' ')
			print("")
		print("")

class MazeWindow(Gtk.Window):
	def __init__(self, maze, animate = False):
		self.maze = maze
		self.animate = animate
		self.solver_thread = None

		Gtk.Window.__init__(self, title="Python Maze")
		self.set_default_size(655, 655)

		self.da = Gtk.DrawingArea()
		self.add(self.da)

		self.connect("destroy", Gtk.main_quit)
		self.connect("key_press_event", self.on_key_press)
		self.da.connect('draw', self.on_draw)

		# Delay do_maze() execution so the GTK window is displayed
		# before the maze is initialized
		Gdk.threads_add_timeout(GLib.PRIORITY_DEFAULT_IDLE, 0.1,
					self.do_maze)

	def monitor_solver(self):
		if self.solver_thread is None:
			return False

		if not self.solver_thread.is_alive():
			self.queue_draw()
			self.solver_thread = None
			return False

		if self.animate:
			self.queue_draw()

		return True

	def start_solver(self):
		if self.solver_thread is not None:
			return

		self.solver_thread = threading.Thread(target=self.maze.solve,
						      args=[ 0.001 if self.animate else 0 ],
						      daemon=True)
		self.solver_thread.start()

		# Start a refresh callback for nice animation
		Gdk.threads_add_timeout(GLib.PRIORITY_DEFAULT_IDLE, 0.1,
					self.monitor_solver)
		return False

	def do_maze(self):
		if self.solver_thread is not None:
			return False

		self.maze.create()
		self.queue_draw()

		# Start the solver thread with a delay
		Gdk.threads_add_timeout(GLib.PRIORITY_DEFAULT_IDLE, 0.1,
					self.start_solver)
		return False

	def set_cr_color(self, cr, color):
		cr.set_source_rgb(color[0], color[1], color[2])

	def on_draw(self, win, cr):
		rect = self.da.get_allocated_size().allocation

		cell_width = int(rect.width / self.maze.num_cols)
		cell_height = int(rect.height / self.maze.num_rows)

		x_padding = int((rect.width - (cell_width * self.maze.num_cols)) / 2)
		y_padding = int((rect.height - (cell_height * self.maze.num_rows)) / 2)

		for row in range(self.maze.num_rows):
			for col in range(self.maze.num_cols):
				cell = self.maze.board[row][col]
				if cell.value == 0:
					color = [ 0, 0, 0 ]
				elif cell.path:
					color = [ 0, 1, 0 ]
				else:
					color = self.maze.board[row][col].color

				if color is None:
					continue

				self.set_cr_color(cr, color)
				cr.rectangle((col * cell_width) + x_padding,
					     (row * cell_height) + y_padding,
					     cell_width, cell_height)
				cr.fill()

	def on_key_press(self, win, event):
		if event.keyval == Gdk.KEY_F5:
			self.do_maze()

def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('-r', '--rows', type=int, default=81, help='Maze rows')
	parser.add_argument('-c', '--cols', type=int, default=81, help='Maze columns')
	parser.add_argument('-C', '--complex', action='store_true', default=False, help='Produce a more complex maze')
	parser.add_argument('-a', '--animate', action='store_true', default=False, help='Slow down solver execution to display a nice animation')
	args = parser.parse_args()

	maze = Maze(args.rows, args.cols, args.complex)
	win = MazeWindow(maze, args.animate)
	win.show_all()
	Gtk.main()

if __name__ == "__main__":
	main()
