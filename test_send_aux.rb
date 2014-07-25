#!/usr/bin/env ruby
#require 'benchmark'

#fnums = ['0971303196', '0981460196', '0971222540']
nums = ['0971717273', '0971222540', '0971303196','0981460196', '0971663173','0986538056','0986548296','0992228109','0981495681','0972886385','0971886385','0971856056','0971611778','0994209974', '0961605976']

35.times do
  nums.each do |n|
    `ruby test_send.rb -t #{n} -m "Prueba de bulk.. bs ns" -q com.smpp_gateway.bulk.sender`
  end
end