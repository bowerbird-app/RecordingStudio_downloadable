import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"

// One "controllers" load covers pinned gem controllers. A per-gem
// lazyLoadControllersFrom scans every data-controller and logs autoload failures.
lazyLoadControllersFrom("controllers", application)
