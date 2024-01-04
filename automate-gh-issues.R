# the template repository (<org>/<repo>)
template_repo <- "elixir-europe-training/ELIXIR-TrP-LessonTemplate-MkDocs"
# the organization in which to search for repos using the template
org <- "elixir-europe-training"

issue_title <- "Update action render_page.yml"

issue_body <-
  "After the update of MkDocs, you will need to install `setuptools` to enable the bibtex plugin. Due to security reasons, it is not straightforward to make workflows part of the template sync. In order to make dependency updates part of the template sync in the future, I have specified the dependencies in a requirements.txt file. 

Please follow the steps below to fix the issue: 

- Update `.github/workflows/render_page.yml`. You can do this by copy-pasting the content of https://github.com/elixir-europe-training/ELIXIR-TrP-LessonTemplate-MkDocs/blob/main/.github/workflows/render_page.yml.
- Manually run the template sync action by clicking: Actions > .github/workflows/template_sync.yml > Run workflow > Run workflow.
- Accept the pull request created by the action (wait until the action has completed and find it at Pull requests)

Please mark this issue as complete if you have (already) fixed this."


# load the PAT
# should contain 
# pat <- "ghp_sdlfkjwerou235098sf"
source(".env.R")

library(httr2)

# parse all repositories in the organziation
parsed <- request("https://api.github.com/orgs/") |>
  req_url_path_append(org) |>
  req_url_path_append("repos") |>
  req_headers(
    Accept = "application/vnd.github+json",
    Authorization = paste("Bearer", pat),
    `X-GitHub-Api-Version` = "2022-11-28",
  ) |>
  req_perform() |> resp_body_json()

# loop over all the repos and identify the repos using the template
# returns a list containing the repo name and the most active contributor
repo_with_template <- list()
for(i in seq(length(parsed))) {
  # get repo full name
  repo_full_name <- parsed[[i]]$full_name
  
  # get repo metadata
  repo_parsed <- request(parsed[[i]]$url) |>
    req_headers(
      Accept = "application/vnd.github+json",
      Authorization = paste("Bearer", pat),
      `X-GitHub-Api-Version` = "2022-11-28",
    ) |>
    req_perform() |>
    resp_body_json()
  
  # get repo contributors
  contr_parsed <- request(parsed[[i]]$contributors_url) |>
    req_headers(
      Accept = "application/vnd.github+json",
      Authorization = paste("Bearer", pat),
      `X-GitHub-Api-Version` = "2022-11-28",
    ) |>
    req_perform() |>
    resp_body_json()
  
  # move to next if no template info
  if(is.null(repo_parsed$template_repository$full_name)) next
  
  # add to list if template repo equals specified template repo
  if (repo_parsed$template_repository$full_name == template_repo) {
    # add a list containing repo full name and most active contributor
    # contributors are ordered by number of contributions, 
    # so taking the first would be the most active contributor
    repo_with_template <- append(repo_with_template,
                                 list(
                                   list(
                                     full_name = repo_full_name,
                                     main_contributor = contr_parsed[[1]]$login
                                   )))
  }
}

# validate choice to send issue to list of repos
repo_names <- sapply(repo_with_template, function(x) x$full_name)
choice <- menu(choices = c("Yes","No"),
               title = paste("You will be sending the issue to the following repos: \n",
                             paste(repo_names, collapse = "\n"), "\nContinue?", 
                             sep = "\n"))

if (switch(choice, TRUE, FALSE)) {
  # send the issues by loping over the list containing repo and contributor
  for(repo_info in repo_with_template) {
    request("https://api.github.com/repos/") |>
      req_url_path_append(repo_info$full_name) |>
      req_url_path_append("issues") |>
      req_method("POST") |>
      req_headers(
        Accept = "application/vnd.github+json",
        Authorization = paste("Bearer", pat),
        `X-GitHub-Api-Version` = "2022-11-28",
      ) |>
      req_body_json(list(title = issue_title,
                    body = issue_body)) |>
      req_perform()
  }
}


