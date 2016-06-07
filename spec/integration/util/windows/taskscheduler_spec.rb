#! /usr/bin/env ruby
require 'spec_helper'

if Puppet.features.microsoft_windows?
  require 'puppet/util/windows/taskscheduler'
  module Puppet
    module Util
      module Windows
        include Win32
      end
    end
  end

  def dummy_time_trigger
    now = Time.now
    {
        'flags'                   => 0,
        'random_minutes_interval' => 0,
        'end_day'                 => 0,
        'end_year'                => 0,
        'minutes_interval'        => 0,
        'end_month'               => 0,
        'minutes_duration'        => 0,
        'start_year'              => now.year,
        'start_month'             => now.month,
        'start_day'               => now.day,
        'start_hour'              => now.hour,
        'start_minute'            => now.min,
        'trigger_type'            => Win32::TaskScheduler::ONCE,
    }
  end
  
end



describe "Puppet::Util::Windows::TaskScheduler", :if => Puppet.features.microsoft_windows? do

  describe '#parameters' do

    let(:resource) { Puppet::Type.type(:scheduled_task).new(:name => SecureRandom.uuid, :command => 'C:\Windows\System32\notepad.exe') }

    it "should read over 300 character arguments" do

      verylongstring = <<-STR
ThisIsALongStringThisIsALongStringThisIsALongStringThisIsALongStringThisIsALongStringThisIsALo
ngStringThisIsALongStringThisIsALongStringThisIsALongStringThisIsALongStringThisIsALongString
ThisIsALongStringThisIsALongStringThisIsALongStringThisIsALongStringThisIsALongStringThisIsA
LongStringThisIsALongS
      STR

      subject = Puppet::Util::Windows::TaskScheduler.new(resource[:name], dummy_time_trigger)
      subject.application_name=(resource[:command])
      subject.parameters=(verylongstring)

      expect(subject.parameters).to eq(verylongstring)
    end
  end
end