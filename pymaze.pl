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
import re

from timeit import default_timer as timer

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
	MIN_NUM_ROWS = 21
	MAX_NUM_ROWS = 499

	MIN_NUM_COLS = 21
	MAX_NUM_COLS = 499

	def __init__(self, num_rows = 21, num_cols = 21, difficult = False):
		self.set_sizes(num_rows, num_cols)
		self.difficult = difficult

		self.board = []
		self.created = False
		self.start_cell = None
		self.end_cell = None
		self.path_solve_time = 0
		self.path_len = 0

	# Row and col numbers must be odd
	def set_sizes(self, rows: int, cols: int):
		if rows < Maze.MIN_NUM_ROWS:
			self.num_rows = Maze.MIN_NUM_ROWS
		elif rows > Maze.MAX_NUM_ROWS:
			self.num_rows = Maze.MAX_NUM_ROWS
		elif not rows & 0x1:
			self.num_rows = rows + 1
		else:
			self.num_rows = rows

		if cols < Maze.MIN_NUM_COLS:
			self.num_cols = Maze.MIN_NUM_COLS
		elif cols > Maze.MAX_NUM_COLS:
			self.num_cols = Maze.MAX_NUM_COLS
		elif not cols & 0x1:
			self.num_cols = cols + 1
		else:
			self.num_cols = cols

		return (self.num_rows, self.num_cols)

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
		self.path_solve_time = 0
		self.path_len = 0
		t = timer()

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
				self.path_solve_time = timer() - t
				self.path_len = 1

				while cell.parent is not None:
					self.board[cell.row][cell.col].path = True
					cell = cell.parent
					self.path_len += 1

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

	def clear(self):
		for row in self.board:
			for cell in row:
				if cell.value != 0:
					cell.value = 2
					cell.color = None
					cell.path = False

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
		self.re = None

		Gtk.Window.__init__(self, title="Python Maze")

		hbox = Gtk.HBox(spacing=3)
		self.add(hbox)

		grid = Gtk.Grid(row_spacing=6, column_spacing=6)
		hbox.pack_start(grid, False, False, 6)
		self.controls_grid = grid

		self.da = Gtk.DrawingArea()
		self.da.set_size_request(500, 500)
		hbox.pack_start(self.da, True, True, 6)

		separator = Gtk.Separator(orientation = Gtk.Orientation.HORIZONTAL)
		grid.add(separator)

		label_rows = Gtk.Label(xalign = 1)
		label_rows.set_text("Rows:")
		grid.attach_next_to(label_rows, separator, Gtk.PositionType.BOTTOM, 1, 1)

		entry = Gtk.Entry()
		entry.set_max_length(3)
		entry.set_width_chars(3)
		entry.set_text(str(self.maze.num_cols))
		entry.props.input_purpose = Gtk.InputPurpose.DIGITS
		entry.connect("insert-text", self.on_insert)
		grid.attach_next_to(entry, label_rows, Gtk.PositionType.RIGHT, 1, 1)
		self.entry_rows = entry

		label_cols = Gtk.Label(xalign = 1)
		label_cols.set_text("Cols:")
		grid.attach_next_to(label_cols, label_rows, Gtk.PositionType.BOTTOM, 1, 1)

		entry = Gtk.Entry()
		entry.set_text(str(self.maze.num_rows))
		entry.set_max_length(3)
		entry.set_width_chars(3)
		entry.props.input_purpose = Gtk.InputPurpose.DIGITS
		entry.connect("insert-text", self.on_insert)
		self.entry_cols = entry
		grid.attach_next_to(entry, label_cols, Gtk.PositionType.RIGHT, 1, 1)

		check = Gtk.CheckButton.new_with_label("Difficult")
		check.set_active(self.maze.difficult)
		check.connect("clicked", self.on_difficult_clicked)
		grid.attach_next_to(check, label_cols, Gtk.PositionType.BOTTOM, 2, 1)

		button = Gtk.Button.new_with_label("New")
		button.connect("clicked", self.on_new_clicked)
		grid.attach_next_to(button, check, Gtk.PositionType.BOTTOM, 2, 1)

		separator = Gtk.Separator(orientation = Gtk.Orientation.HORIZONTAL)
		grid.attach_next_to(separator, button, Gtk.PositionType.BOTTOM, 2, 1)

		check = Gtk.CheckButton.new_with_label("Animate")
		check.set_active(self.animate)
		check.connect("clicked", self.on_animate_clicked)
		grid.attach_next_to(check, separator, Gtk.PositionType.BOTTOM, 2, 1)

		button = Gtk.Button.new_with_label("Solve")
		button.connect("clicked", self.on_solve_clicked)
		grid.attach_next_to(button, check, Gtk.PositionType.BOTTOM, 2, 1)

		label = Gtk.Label()
		grid.attach_next_to(label, button, Gtk.PositionType.BOTTOM, 2, 1)
		self.path_info_label = label

		self.connect("destroy", Gtk.main_quit)
		self.connect("key_press_event", self.on_key_press)
		self.da.connect('draw', self.on_draw)

		self.create_maze()

	def on_insert(self, entry, text, text_len, pos):
		if self.re is None:
			self.re = re.compile("\D+")

		if self.re.search(text):
			entry.emit_stop_by_name("insert-text");
			return True

		return False

	def on_new_clicked(self, button):
		self.create_maze()
		self.queue_draw()

	def on_solve_clicked(self, button):
		self.maze.clear()
		self.solve_maze()

	def on_difficult_clicked(self, button):
		self.maze.difficult = button.get_active();

	def on_animate_clicked(self, button):
		self.animate = button.get_active();

	def monitor_solver(self):
		if self.solver_thread is None:
			return False

		if not self.solver_thread.is_alive():
			self.queue_draw()
			self.solver_thread = None
			self.controls_grid.set_sensitive(True)
			info = "Length: %d\nTime: %.3fs" % (self.maze.path_len,
							    self.maze.path_solve_time)
			self.path_info_label.set_text(info)
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

	def create_maze(self):
		if self.solver_thread is not None:
			return

		rows = int(self.entry_rows.get_text())
		cols = int(self.entry_cols.get_text())
		(rows, cols) = self.maze.set_sizes(rows, cols)
		self.entry_rows.set_text(str(rows))
		self.entry_cols.set_text(str(cols))

		self.maze.create()

	def solve_maze(self):
		if self.solver_thread is not None:
			return

		self.controls_grid.set_sensitive(False)

		# Start the solver thread with a delay
		Gdk.threads_add_timeout(GLib.PRIORITY_DEFAULT_IDLE, 0.1,
					self.start_solver)
		return

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
			self.create_maze()
			self.solve_maze()

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
