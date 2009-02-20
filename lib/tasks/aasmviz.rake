# Need some way to get the list of transactions for a given event.
module AASM
  module SupportingClasses
    class Event
      def all_transitions
        @transitions
      end
    end
  end
end

namespace :aasm do
  desc <<-DESC
Show visual of the state machine for each model.  A png will be generated for
each model including AASM and will reside in /tmp/aasm_model_name.png
  DESC
  task :visual => :environment do
    # Loop through each of the models and see if (1) they are based directly on
    # ActiveRecord::Base and (2) whether they have a SM defined.
    Dir.glob("app/models/*rb") do |f|
      f.match(/\/([a-z_]+).rb/)
      out_png = File.join("/tmp", "aasm_#{$1}.png")
      classname = $1.camelize
      klass = Kernel.const_get classname

      if klass.superclass == ActiveRecord::Base && klass.respond_to?(:aasm_states)
        puts "file://#{out_png}"
        IO.popen("dot -Tpng > #{out_png}", "w") do |graph|
          graph.puts "digraph sm_#{classname} {"
          graph.puts "rankdir=LR;"
          graph.puts "#{klass.aasm_initial_state} [ shape = doublecircle ]"

          # We need an instance method of the klass to make use of the aasm
          # instance methods
          k = klass.new

          # Emit the nodes of each of the states of the SM.  Start and End
          # states will appear in an double circle.
          klass.aasm_states.each do |state|
            next if state.name == klass.aasm_initial_state # intial state handled above
            if k.aasm_events_for_state(state.name).empty?  # No events => end state
              graph.puts "#{state.name} [ shape = doublecircle ]"
            else
              graph.puts state.name
            end
          end

          # Add the transitions for each event, labelling each transition
          # with the event name.
          klass.aasm_events.each do |name, event|
            event.all_transitions.each do |t|
              graph.puts "#{t.from} -> #{t.to} [ label = \"#{name}\" ]"
            end
          end
          graph.puts "}"
        end
      end
    end
  end
end

