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

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
from gi.repository import Gdk

class Cell:
	def __init__(self, row, col, parent = None):
		self.row = row
		self.col = col
		self.value = 0
		self.path = False
		self.color = None

	# Compare cells
	def __eq__(self, cell):
		return self.row == cell.row and self.col == cell.col

	# Sort cells
	def __lt__(self, cell):
		return self.valuc < cell.value

	# Print cell
	def __repr__(self):
		return ('(row={0}, col={1}, h={2})'.format(self.row, self.col, self.value))

class Maze:
	def __init__(self, num_rows = 21, num_cols = 21, difficult = False):
		# Row and col numbers must be odd
		self.num_rows = num_rows + 1 if not num_rows & 0x1 else num_rows
		self.num_cols = num_cols + 1 if not num_cols & 0x1 else num_cols
		self.difficult = difficult

		self.board = []
		self.start_cell = None
		self.end_cell = None

		self.do_maze()

	def do_maze(self):
		self.init_board()
		self.create()
		self.solve()
		self.mark_solution_path()

	def init_board(self):
		self.board.clear()

		for r in range(self.num_rows):
			row = []
			for c in range(self.num_cols):
				cell = Cell(r, c)
				if r % 2 and c % 2:
					cell.value = 1
				else:
					cell.value = 0
				row.append(cell)
			self.board.append(row)

	def is_wall(self, row, col):
		return self.board[row][col].value == 0

	def create(self):
		stack = []
		neighbours = [ Cell(-2, 0), Cell(0, 2), Cell(2, 0), Cell(0, -2) ]
		walls = [ Cell(-1, 0), Cell(0, 1), Cell(1, 0), Cell(0, -1) ]

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

	def are_same_cells(self, cell1, cell2):
		return cell1.row == cell2.row and cell1.col == cell2.col

	def is_start(self, cell):
		return self.are_same_cells(cell, self.start_cell)

	def is_end(self, cell):
		return self.are_same_cells(cell, self.end_cell)

	def solve(self):
		neighbours = [ Cell(-1, 0), Cell(0, 1), Cell(1, 0), Cell(0, -1) ]
		stack = []

		self.start_cell.value = 3
		stack.append(self.start_cell)

		while len(stack):
			cell = stack.pop(-1)
			d = cell.value
			sel_d = d

			sel_cell = None
			for i in range(4):
				n = neighbours[i]

				if (cell.row + n.row < 0 or
				    cell.row + n.row >= self.num_rows or
				    cell.col + n.col < 0 or
				    cell.col + n.col >= self.num_cols):
					continue

				n_cell = self.board[cell.row + n.row][cell.col + n.col]

				if n_cell.value == 0:
					continue

				if n_cell.value == 2:
					sel_cell = n_cell
					break

				if n_cell.value > sel_d + 1:
					sel_d = sel_d + 1
					sel_cell = n_cell

			if not sel_cell is None:
				stack.append(cell)
				sel_cell.value = d + 1
				stack.append(sel_cell)


	def mark_solution_path(self):
		neighbours = [ Cell(-1, 0), Cell(0, 1), Cell(1, 0), Cell(0, -1) ]

		cell = self.end_cell
		while not self.is_start(cell):
			row = cell.row
			col = cell.col
			d = cell.value
			cell.path = True

			for i in range(4):
				n = neighbours[i]
				n_row = row + n.row
				n_col = col + n.col

				if n_row < 0 or n_row >= self.num_rows or n_col < 0 or n_col >= self.num_cols:
					continue

				v = self.board[n_row][n_col].value
				if v > 2 and v < d:
					d = v
					cell = self.board[n_row][n_col]

		self.start_cell.path = True

	def show_maze(self):
		for row in self.maze:
			for v in row:
				print(" " if v else "X", end = ' ')
			print("")
		print("")

class MazeWindow(Gtk.Window):
	def __init__(self, maze):
		self.maze = maze

		Gtk.Window.__init__(self, title="Python Maze")
		self.set_default_size(655, 655)

		self.da = Gtk.DrawingArea()
		self.add(self.da)

		self.connect("destroy", Gtk.main_quit)
		self.connect("key_press_event", self.on_key_press)
		self.da.connect('draw', self.on_draw)

		self.maze = maze

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
			self.maze.do_maze()
			win.queue_draw()

def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('-r', '--rows', type=int, default=81, help='Maze rows')
	parser.add_argument('-c', '--cols', type=int, default=81, help='Maze columns')
	parser.add_argument('-C', '--complex', action='store_true', default=False, help='Produce a more complex maze')
	args = parser.parse_args()

	maze = Maze(args.rows, args.cols, args.complex)
	win = MazeWindow(maze)
	win.show_all()
	Gtk.main()

if __name__ == "__main__":
	main()
