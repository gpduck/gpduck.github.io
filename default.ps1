
Task default -Depends build

Task build -Depends sass,Jekyll {
	
}

Task sass {
	sass .\sass\site_bootstrap.scss .\css\site_bootstrap.css
}

Task Jekyll {
	jekyll build --config "_config.yml,_configLocal.yml" --destination .\_site\
}