#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'json'
require_relative 'lib/widget'
require_relative 'lib/config'
require_relative 'lib/bar'
require_relative 'lib/util'

Process.setproctitle("ruby-bar")

bar_config = BarConfig.new(colour_file: '/home/toshokan/.Xresources.d/bar-colours.json')

widgets = {
  bspc: BspcReportListenerWidget.new,
  title: WindowTitleWidget.new,
  multi: MultiWidget.new(:multi,
                         bar_config.settings[:bar_fifo],
                         vol: VolumeWidget.new('Master'),
                         song: MPCStatusWidget.new),
  sys: ClockWidget.new,
  net: NetworkWidget.new('wlp2s0'),
  batt: BatteryWidget.new('BAT0'),
}

# Formatter should accept a widget hash and a monitor number
format = lambda { |w,m| "%{l}#{w[:bspc][m] unless w[:bspc].nil?}%{c}#{w[:title]}%{r}#{w[:net]} | #{w[:batt]} | #{w[:multi]} | #{w[:sys]}" }
lemonbar_format = LemonBarFormat.new(MultiMonitorUtils::gen_format_fn(format), bar_config, widgets)

lemonbar = LemonBar.new(bar_config, lemonbar_format)
lemonbar.run

fifo = bar_config.settings[:bar_fifo]
if File.exist?(fifo)
  File.delete(fifo)
end
File.mkfifo(fifo)

# we need to hang on to a write fd in this process, otherwise we'll get an EOF after the first widget finishes writing to it
File.open(fifo, "r+") do |f|
  f.each_line do |line|
    case line
    when /^S/
      tag = line[1..-2].to_sym # -2 to strip terminal newline
      widgets[tag].switch
    end
  end
end
