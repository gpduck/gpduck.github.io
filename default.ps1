
Task default -Depends build

Task build -Depends sass {
	
}

Task sass {
	sass .\sass\site_bootstrap.scss .\css\site_bootstrap.css
}