import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"

// Lazy load controllers from the host app, FlatPack, and Attachable on first use.
lazyLoadControllersFrom("controllers", application)
lazyLoadControllersFrom("controllers/recording_studio_attachable", application)
