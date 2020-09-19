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

class Maze:
	def __init__(self, num_rows = 21, num_cols = 21, difficult = False):
		self.num_rows = num_rows
		self.num_cols = num_cols
		self.difficult = difficult

		self.board = []
		self.start_cell = []
		self.end_cell = []

		self.init_board()
		self.create()
		self.solve()

	def init_board(self):
		self.board.clear()

		for r in range(self.num_rows):
			row = []
			for c in range(self.num_cols):
				row.append(1 if r % 2 and c % 2 else 0)
			self.board.append(row)

	def is_wall(self, row, col):
		return self.board[row][col] == 0

	def create(self):
		stack = []
		neighbours = [ [ -2, 0 ], [ 0, 2 ], [ 2, 0 ], [ 0, -2 ] ]
		walls = [ [ -1, 0 ], [ 0, 1 ], [ 1, 0 ], [ 0, -1 ] ]

		row = random.randrange(1, self.num_rows, 2);
		col = random.randrange(1, self.num_cols, 2);
		self.board[row][col] = 2

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

				if n_row < 0 or n_row >= self.num_rows or n_col < 0 or n_col >= self.num_cols:
					continue

				if self.board[n_row][n_col] == 2:
					continue

				stack.append([row, col])

				self.board[n_row][n_col] = 2
				stack.append([n_row, n_col])

				# Remove wall between cells
				w = walls[(i + r) % 4]
				self.board[row + w[0]][col + w[1]] = 2

				break

			# Break the wall
			self.board[row][col] = 2

		for row in range(self.num_rows):
			if self.board[row][1]:
				self.board[row][0] = 2
				self.start_cell = [ row, 0 ]
				break

		for row in range(self.num_rows - 1, 0, -1):
			if self.board[row][self.num_cols - 2]:
				self.board[row][self.num_cols - 1] = 2
				self.end_cell = [ row, self.num_cols - 1 ]
				break

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

			self.board[row][col] = 2

	def are_same_cells(self, cell1, cell2):
		return cell1[0] == cell2[0] and cell1[1] == cell2[1]

	def is_start(self, cell):
		return self.are_same_cells(cell, self.start_cell)

	def is_end(self, cell):
		return self.are_same_cells(cell, self.end_cell)

	def solve(self):
		neighbours = [ [ -1, 0 ], [ 0, 1 ], [ 1, 0 ], [ 0, -1 ] ]
		stack = []
		self.max_distance = 0

		cell = self.start_cell
		self.board[cell[0]][cell[1]] = 3
		stack.append(cell)

		solved = not True

		while not solved:
			cell = stack.pop(-1)
			row = cell[0]
			col = cell[1]
			d = self.board[row][col]
			if d > self.max_distance:
				self.max_distance = d

			r = random.randint(0, 3)
			for i in range(4):
				n = neighbours[(i + r) % 4]
				n_row = row + n[0]
				n_col = col + n[1]

				if n_row < 0 or n_row >= self.num_rows or n_col < 0 or n_col >= self.num_cols:
					continue

				if self.is_end([n_row, n_col]):
					self.board[n_row][n_col] = d + 1
					solved = True
					break

				if self.board[n_row][n_col] == 0 or self.board[n_row][n_col] > 2:
					continue

				stack.append([row, col])

				self.board[n_row][n_col] = d + 1
				stack.append([n_row, n_col])
				break

		cell = self.end_cell
		while not self.is_start(cell):
			row = cell[0]
			col = cell[1]
			d = self.board[row][col]
			self.board[row][col] = -1

			for i in range(4):
				n = neighbours[i]
				n_row = row + n[0]
				n_col = col + n[1]

				if n_row < 0 or n_row >= self.num_rows or n_col < 0 or n_col >= self.num_cols:
					continue

				v = self.board[n_row][n_col]
				if v > 2 and v < d:
					d = v
					cell = [n_row, n_col]

		self.board[self.start_cell[0]][self.start_cell[1]] = -1

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
		self.set_default_size(maze.num_cols * 10 + 20,
				      maze.num_rows * 10 + 20)

		da = Gtk.DrawingArea()
		self.add(da)

		self.connect("destroy", Gtk.main_quit)
		self.connect("key_press_event", self.on_key_press)
		da.connect('draw', self.on_draw)

		self.maze = maze

	def on_draw(self, win, cr):
		for row in range(self.maze.num_rows):
			for col in range(self.maze.num_cols):
				v = self.maze.board[row][col]
				if v > 0:
					continue

				r = g = b = 0

				if v == -1:
					r = 1

				cr.set_source_rgb(r, g, b)
				cr.rectangle(col * 10 + 10, row * 10 + 10, 10, 10)
				cr.fill()

	def on_key_press(self, win, event):
		if event.keyval == Gdk.KEY_F5:
			self.maze.init_board()
			self.maze.create()
			self.maze.solve()
			win.queue_draw()

def main():
	maze = Maze(71, 71, False)
	win = MazeWindow(maze)
	win.show_all()
	Gtk.main()

if __name__ == "__main__":
	main()
