#!/usr/bin/env ruby
# coding: utf-8
require 'pdf/reader'
require 'date'
require 'ibanizator'
fulltext = ""

$account_instrument_sell = "Einnahmen:Privat:NichtSteuerrelevant:Wertpapierverkaeufe"
$account_instrument_buy = "Ausgaben:Privat:NichtSteuerrelevant:Wertpapierkaeufe"
$account_interest = "Einnahmen:Privat:NichtSteuerrelevant:ZinsenDividenden"
$account_prefix ="Besitzposten:Privatvermoegen:Umlaufvermoegen:LiquideMittel:Consorsbank:"
$account_unknown ="OffeneBuchungen"
$year = ""

def parsentries(fulltext)
  entries = Array.new

  textarray=fulltext.split(/\n/)
  #  pp textarray
  textarray.each_with_index do | line,index|
    if /^[A-Z].*[-\+]$/ =~ line
      entry = Array.new
      i=0
      while textarray[index+i] != "" || i<=2 do
        if textarray[index+i] != ""
          entry << textarray[index+i]
        end
        i=i+1
      end
      entries << entry
    end
  end
  entries
end

def entries2ledger(entries,statement_data)
  def format_ledger(entrydata,statement_data)
  #Date.new(new_year, entrydata[:date].month, entrydata[:date].day)
  
    #print "#{Date.new($year.to_i, entrydata[:date].month, entrydata[:date].day).strftime("%Y/%m/%d")}=#{Date.new($year.to_i, entrydata[:valuta].month, entrydata[:valuta].day).strftime("%Y/%m/%d")} "
    #puts entrydata[:ledgerline]
    #puts "    #{$account_prefix}#{statement_data[:iban]}\t#{entrydata[:value].to_s.gsub('.',',')} #{statement_data[:currency]}"
    #puts "    #{entrydata[:toaccount]}"
    entrydata.each_with_index  do |(key,value), index|
	  if key == :date # Replace :specific_key with the key you're checking for
        entrydata[key] = Date.new($year.to_i, value.month, value.day) # Set the new value you want
      end
	  if key == :valuta # Replace :specific_key with the key you're checking for
        entrydata[key] = Date.new($year.to_i, value.month, value.day) # Set the new value you want
      end
      print value
      print ', ' unless index == entrydata.size - 1
    end
	puts # For a newline at the end
  end

  entries.each do |entry|
    entrydata={}
    #    entrydata.merge!(raw: entry)
    #    pp entry
    entry_type=entry.first.scan(/^.*?  /).first[..-3].sub(/ NR\..*/,"").to_s
    #entrydata.merge!(entrytype: entry_type) # Dont print entry type, irrelevant for csvs
    case entry_type
    when "EFFEKTEN"
      if result=/EFFEKTEN.+(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\w\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)
        if result=/WP-ABRECHNUNG (\d+)/.match(entry[1])
          entrydata.merge!(wpabrechnung: result[1])
        end
        if result=/ +(\w+) +WKN: (\w{6})/.match(entry[2])
          entrydata.merge!(buysell: result[1])
          entrydata.merge!(wkn: result[2])
        end
        if result=/ +(.+)/.match(entry[3])
          entrydata.merge!(instrument: result[1])
        end
        entrydata.merge!(ledgerline: "#{entrydata[:buysell]} #{entrydata[:instrument]}")
        if entrydata[:buysell] == "Verkauf"
          entrydata.merge!(toaccount: $account_instrument_sell)
        elsif entrydata[:buysell] == "Kauf"
          entrydata.merge!(toaccount: $account_instrument_buy)
        end
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end
    when "ZINS/DIVID."
      if result=/ZINS\/DIVID. +(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)

        if result=/ +(.+)/.match(entry[1])
          entrydata.merge!(instrument: result[1])
        end
        if result=/ +WKN: (\w{6})/.match(entry[2])
          entrydata.merge!(wkn: result[1])
        end
        entrydata.merge!(ledgerline: "#{entry_type} #{entrydata[:instrument]}")
        entrydata.merge!(toaccount: $account_interest)
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end
    when "SOLZ 1"
      if result=/SOLZ 1 +(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)

        if result=/ +(.+)/.match(entry[1])
          entrydata.merge!(title: result[1])
        end
        entrydata.merge!(comment: (entry[2]+entry[3]).split.join(' '))
        entrydata.merge!(ledgerline: "#{entry_type} #{entrydata[:title]}")
        entrydata.merge!(toaccount: $account_instrument_sell)
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end
   when "SOLZ 1 GUTS."
      if result=/SOLZ 1 GUTS. +(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)

        if result=/ +(.+)/.match(entry[1])
          entrydata.merge!(title: result[1])
        end
#        pp entry
        entrydata.merge!(comment: entry[2].split.join(' '))
        entrydata.merge!(ledgerline: "#{entry_type} #{entrydata[:title]}")
        entrydata.merge!(toaccount: $account_instrument_sell)
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end

    when "KAPST1 GUTS."
      if result=/KAPST1 GUTS. +(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)

        if result=/ +(.+)/.match(entry[1])
          entrydata.merge!(title: result[1])
        end
        entrydata.merge!(comment: (entry[2]+entry[3]).split.join(' '))
        entrydata.merge!(ledgerline: "#{entry_type} #{entrydata[:title]}")
        entrydata.merge!(toaccount: $account_instrument_sell)
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end

    when "EURO-UEBERW."
      if result=/EURO-UEBERW..+(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
		#puts "DAMN DATES:  '#{result[1] + '.' + $year}'"
        #entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)
        entrydata.merge!(recipient: entry[1].split.join(' '))

        (bic,iban)=entry[2].split.join(' ').split(' ')
        entrydata.merge!(bic: bic.tr('<>',''))
        entrydata.merge!(iban: Ibanizator.iban_from_string(iban))

        entrydata.merge!(reason: entry[3].to_s.split.join(' '))
        
        entrydata.merge!(ledgerline: "#{entry_type} #{entrydata[:recipient]}")
        entrydata.merge!(toaccount: $account_unknown)
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end
	  
	when "GEHALT/RENTE"
      if result=/GEHALT\/RENTE..+(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        #entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)
        entrydata.merge!(recipient: entry[1].split.join(' '))

        (bic,iban)=entry[2].split.join(' ').split(' ')
        entrydata.merge!(bic: bic.tr('<>',''))
        entrydata.merge!(iban: Ibanizator.iban_from_string(iban))

        entrydata.merge!(reason: entry[3].to_s.split.join(' '))
        
        entrydata.merge!(ledgerline: "#{entry_type} #{entrydata[:recipient]}")
        entrydata.merge!(toaccount: $account_unknown)
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end

	when "LASTSCHRIFT"
      if result=/LASTSCHRIFT.+(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        #entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)
        entrydata.merge!(recipient: entry[1].split.join(' '))
		
		cleaned_string = entry[2].gsub(/[<>]/, '').strip
        (bic,iban)=cleaned_string.split(/\s+/)
        entrydata.merge!(bic: bic.tr('<>',''))
        entrydata.merge!(iban: Ibanizator.iban_from_string(iban))

        entrydata.merge!(reason: entry[3].to_s.split.join(' '))
        
        entrydata.merge!(ledgerline: "#{entry_type} #{entrydata[:recipient]}")
        entrydata.merge!(toaccount: $account_unknown)
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end

	when "GIROCARD"
      if result=/GIROCARD.+(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        #entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)
        entrydata.merge!(recipient: entry[1].split.join(' '))
		
		cleaned_string = entry[2].gsub(/[<>]/, '').strip
        (bic,iban)=cleaned_string.split(/\s+/)
        entrydata.merge!(bic: bic.tr('<>',''))
        entrydata.merge!(iban: Ibanizator.iban_from_string(iban))

        entrydata.merge!(reason: entry[3].to_s.split.join(' '))
        
        entrydata.merge!(ledgerline: "#{entry_type} #{entrydata[:recipient]}")
        entrydata.merge!(toaccount: $account_unknown)
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end

    when "GUTSCHRIFT"
      if result=/GUTSCHRIFT.+(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        #entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)
        entrydata.merge!(recipient: entry[1].split.join(' '))

        (bic,iban)=entry[2].split.join(' ').split(' ')
        entrydata.merge!(bic: bic.tr('<>',''))
        entrydata.merge!(iban: Ibanizator.iban_from_string(iban))

        entrydata.merge!(reason: (entry[3].to_s+entry[4].to_s).split.join(' '))
        
        entrydata.merge!(ledgerline: "#{entry_type} #{entrydata[:recipient]}")
        entrydata.merge!(toaccount: $account_unknown)
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end

    when "DAUERAUFTRAG"
      if result=/DAUERAUFTRAG NR.(\d+) +(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        #entrydata.merge!(id: result[1])
        entrydata.merge!(date: Date.strptime(result[2],'%d.%m'))
        #entrydata.merge!(pnnnr: result[3])
        entrydata.merge!(valuta: Date.strptime(result[4],'%d.%m'))
        value = result[5].to_s.gsub('.', '').gsub(',','.').to_f
        if result[6] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)
        entrydata.merge!(recipient: entry[1].split.join(' '))

        (bic,iban)=entry[2].split.join(' ').split(' ')
        entrydata.merge!(bic: bic.tr('<>',''))
        entrydata.merge!(iban: Ibanizator.iban_from_string(iban))

        entrydata.merge!(ledgerline: "#{entry_type} #{entrydata[:recipient]}")
        entrydata.merge!(toaccount: $account_unknown)

      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end

	when "ABSCHLUSS"
		if result=/ABSCHLUSS +(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
		entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        #entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
		value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)
		description, value = entry[1].match(/(.*?)(\d+[\.,]\d+\+?)$/).captures

		#sign = value[-1] if value[-1] =~ /[+-]/
		# Remove the sign from the number part
		#number_part = value[0..-2].gsub('.', '') # Remove dots

		# Replace the comma with a dot for float conversion, if needed
		#number_part = number_part.gsub(',', '.')

		value = value.to_s.gsub('.', '').to_f
        if result[6] == '-'
          value=value*-1
        end

		# Format the output to keep the original comma
		#formatted_value = "#{sign}#{number_part.gsub('.', ',')}"
		entrydata.merge!(value: value)
		
      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end

    when "DEV/SORTEN"
      if result=/DEV\/SORTEN +(\d\d\.\d\d)\. +(\d+) +(\d\d\.\d\d)\. +([\d\.\,]+)([+-])/.match(entry[0])
        entrydata.merge!(date: Date.strptime(result[1],'%d.%m'))
        entrydata.merge!(pnnnr: result[2])
        entrydata.merge!(valuta: Date.strptime(result[3],'%d.%m'))
        value = result[4].to_s.gsub('.', '').gsub(',','.').to_f
        if result[5] == '-'
          value=value*-1
        end
        entrydata.merge!(value: value)
        entrydata.merge!(reason: (entry[1].to_s+entry[2].to_s).to_s.split.join(' '))
        entrydata.merge!(ledgerline: "#{entry_type}")
        entrydata.merge!(toaccount: $account_unknown)

      else
        puts "ERROR: could not parse '#{entry[0]}'"
        exit
      end

    else
      puts "ERROR: unknown entry_type '#{entry_type}'"
      pp entry
      exit
    end
    format_ledger(entrydata,statement_data)
    #    pp entrydata
  end
end

def parse_general_statement_data(fulltext)
  date=Date.new
  iban=nil
  currency=nil
  #  pp fulltext
  fulltext.split(/\n/).each do |line|
    result=/Datum +([\d\.]+)/.match(line)
    if result
      date=Date.strptime((result[1]),'%d.%m.%y')
    end
    result=/IBAN +(.+)/.match(line)
    if result
      if Ibanizator.iban_from_string(result[1]).valid?
        iban=Ibanizator.iban_from_string(result[1])
      else
        puts "ERROR: Invalid IBAN found : '#{result[1]}'"
        exit
      end
    end
    result=/Kontowährung +(\w{3})/.match(line)
    if result
      currency=result[1]
    end
  end
  $year = date.year
  {date: date, iban: iban, currency: currency}
end

# MAIN

reader = PDF::Reader.new(ARGV.first)
reader.pages.each do |page|
  fulltext=fulltext+page.text
end

#puts fulltext
puts "Buchung,Valuta,Betrag,Sender / Empfänger,BIC,IBAN,Buchungstext,Verwendungszweck,Kategorie,Stichwörter"
statement_data=parse_general_statement_data(fulltext)
#pp statement_data
entries=parsentries(fulltext)
entries2ledger(entries,statement_data)
