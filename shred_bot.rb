require 'webdrivers'
require 'selenium-webdriver'
require './creds'


## Initialize our globals
Selenium::WebDriver.logger.level = :debug
Selenium::WebDriver.logger.output = '/dev/null' # send this to a local file if you want to debug
DRIVER = Selenium::WebDriver.for :chrome
WAIT = Selenium::WebDriver::Wait.new(:timeout => 15)
DRIVER.manage.new_window(:window)


def logout
  # they have terrible logout click path so just pulling the plug on cookies instead
  DRIVER.manage.delete_all_cookies
  puts "☠️ \tLogged out"
  return
end

def login(skier)  
  # navigate to ikon account page
  DRIVER.get 'https://account.ikonpass.com/en/login'
sleep(1)
  
  # ***** Login Page *****
  email_box = DRIVER.find_element(id: 'email')
  email_box.send_keys(skier[:email])
  password_box = DRIVER.find_element(id: 'sign-in-password')
  password_box.send_keys(skier[:password], :return)
  puts "👨‍💻 \tLogged in as " + skier[:email] + " *hack hack hack hack hack*"
  

  # ***** Account Page *****
  # use an explicit wait to avoid 'no such element' error while loading account page
  res_button = WAIT.until{ DRIVER.find_element(xpath: '//*[@id="root"]/div/div/main/section[1]/div/div[1]/div/a') } # Make a Reservation
  res_button.click  


  # ***** Resort Selector Page *****
  search_bar = WAIT.until{ DRIVER.find_element(xpath: '//*[@id="root"]/div/div/main/section[2]/div/div[2]/div[2]/div[1]/div[1]/div/div/div[1]/input') }
  search_bar.send_keys(RESORT)
  search_bar.send_keys(:arrow_down)
  search_bar.send_keys(:return)
  DRIVER.find_element(xpath: '//*[@id="root"]/div/div/main/section[2]/div/div[2]/div[2]/div[2]/button').click # Continue
  sleep(2)
  
  puts "🚠 \tLoaded up " + RESORT
  
  
end


def checkDates(dates)
  
  for date, date_idx in dates 
  
    target_month = date.split(" ")[0]
    target_day = date.split(" ")[1]
    
    # ***** Month Selector Page *****
    month = DRIVER.find_element(xpath: '//*[@id="root"]/div/div/main/section[2]/div/div[2]/div[3]/div[1]/div[1]/div[1]/div/div[1]/div[2]/span')
    until month.text.include? target_month
      DRIVER.find_element(xpath: '//*[@id="root"]/div/div/main/section[2]/div/div[2]/div[3]/div[1]/div[1]/div[1]/div/div[1]/div[2]/button[2]').click
    end
    
    # ***** Date Selector Page *****
    available = false
    sleep(1) # for some reason the explicit wait doesn't work here so use sleep
    # all available dates are of the class DayPicker-Day so iterate through all of them until specified date is found
    day_picker = WAIT.until{ DRIVER.find_elements(class: 'DayPicker-Day') }
    
    # select date and check availability
    for day in day_picker
      if day.text.eql? target_day
        day.click
        
        # oh boy forgive me this is gnarly. have to check status of that day now
        x = DRIVER.find_element(xpath: "//h2[text() = 'No Reservations Available']") rescue nil
        if x.nil? 
          x = DRIVER.find_element(xpath: "//h2[text() = 'Reservation Details']") rescue nil 
          if x.nil? 
            puts "🔥 \t" + date + " specified date available. Hell ya!!!"
            available = true
          else 
            puts "🤔 \t" + date + " lol we already have that date reserved"  
          end 
        else
          puts "😭 \t" + date + " unavailable, try again later"
        end
        
      end
    end
    
    next if !available # move on to next date in choices if this one was dead
    
    # save and continue
    begin
      save = DRIVER.find_element(xpath: '//*[@id="root"]/div/div/main/section[2]/div/div[2]/div[3]/div[1]/div[2]/div/div[3]/button[1]') # Save
      save.click
    rescue => exception
      puts "🤷‍♂️ \tsave button wasn't there idk gave up"
      next 
    end
    continue = WAIT.until{ DRIVER.find_element(xpath: '//*[@id="root"]/div/div/main/section[2]/div/div[2]/div[3]/div[2]/button') } # Continue to Confirm
    continue.click
    
  
    # ***** Confirmation Page *****
    DRIVER.find_element(class: 'input').click # click confirmation checkbox
    sleep(1)
    confirm = WAIT.until{ DRIVER.find_element(xpath: '//*[@id="root"]/div/div/main/section[2]/div/div[2]/div[4]/div/div[5]/button/span') } # Confirm Reservations
    confirm.click
    sleep(1)
    puts "✅ \treservation confirmed!"
    dates.delete_at(date_idx)
  
  
    # Success! Now lets go back to make another reservation
    confirm = WAIT.until{ DRIVER.find_element(xpath: '//*[@id="root"]/div/div/main/section[2]/div/div/div[3]/a[2]') } 
    confirm.click
    # now you are back on the date select page.. still on same resort
  end
  
  puts "👋 \tall dates have been tried!"
  
end



begin
  
  while !SKICREW.empty?
  
    for skier, skier_idx in SKICREW
      login(skier)
      checkDates(skier[:dates])
      logout
      
      SKICREW.delete_at(skier_idx) if skier[:dates].empty? 
      puts "😴 \tsleeping for a minute to throw off the 👮‍♀️"
      sleep(60)  # wait a minute before logging in as next person
    end
    
    puts "😴 \tsleeping for 15 minutes to throw off the 👮‍♀️"
    sleep(15 * 60) # wait 20 minutes before trying again
  end
ensure
  DRIVER.quit
end