// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"
import "lexxy"

// Pages the iOS app keeps for offline use load without Turbo Drive: links are
// handed to the app, which opens the kept copy (ios/Beeline/OfflinePageView.swift).
if (window.beelineOffline) Turbo.session.drive = false
