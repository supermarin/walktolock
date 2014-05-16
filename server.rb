require 'sinatra'

get '/lock' do
  system('open /System/Library/Frameworks/ScreenSaver.framework/Versions/A/Resources/ScreenSaverEngine.app')
end

