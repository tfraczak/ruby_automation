all_text = []

text = gets.chomp.strip

while text != '$end'
  all_text << text
  text = gets.chomp.strip
end

puts all_text.join("\n")
