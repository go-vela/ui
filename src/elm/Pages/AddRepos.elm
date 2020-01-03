{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.AddRepos exposing (view)

import Dict
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , details
        , div
        , h1
        , p
        , span
        , summary
        , text
        )
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import Search
    exposing
        ( filterRepo
        , repoSearchBarGlobal
        , repoSearchBarLocal
        , searchFilterGlobal
        , searchFilterLocal
        , shouldSearch
        )
import Util
import Vela
    exposing
        ( EnableRepo
        , EnableRepos
        , Org
        , RepoSearchFilters
        , Repositories
        , Repository
        , Search
        , SourceRepositories
        )


{-| view : takes model and renders account page for adding repos to overview
-}
view : WebData SourceRepositories -> RepoSearchFilters -> Search msg -> EnableRepo msg -> EnableRepos msg -> Html msg
view sourceRepos sourceSearchFilters search enableRepo enableRepos =
    let
        loading =
            div []
                [ h1 []
                    [ text "Loading your Repositories"
                    , span [ class "loading-ellipsis" ] []
                    ]
                , p []
                    [ text <|
                        "Hang tight while we grab the list of repositories that you have access to from Github. If you have access to "
                            ++ "a lot of organizations and repositories this might take a little while."
                    ]
                ]
    in
    case sourceRepos of
        RemoteData.Success repos ->
            div [ class "source-repos", Util.testAttribute "source-repos" ]
                [ repoSearchBarGlobal sourceSearchFilters search
                , viewSourceRepos repos sourceSearchFilters search enableRepo enableRepos
                ]

        RemoteData.Loading ->
            loading

        RemoteData.NotAsked ->
            loading

        RemoteData.Failure _ ->
            div []
                [ p []
                    [ text <|
                        "There was an error fetching your available repositories... Click Refresh or try again later!"
                    ]
                ]


{-| viewSourceRepos : takes model and source repos and renders them based on user search
-}
viewSourceRepos : SourceRepositories -> RepoSearchFilters -> Search msg -> EnableRepo msg -> EnableRepos msg -> Html msg
viewSourceRepos sourceRepos sourceSearchFilters search enableRepo enableRepos =
    if shouldSearch <| searchFilterGlobal sourceSearchFilters then
        -- Search and render repos using the global filter
        searchReposGlobal sourceSearchFilters sourceRepos enableRepo

    else
        -- Render repos normally
        sourceRepos
            |> Dict.toList
            |> Util.filterEmptyLists
            |> List.map (\( org, repos_ ) -> viewSourceOrg sourceSearchFilters org repos_ search enableRepo enableRepos)
            |> div [ class "repo-list" ]


{-| viewSourceOrg : renders the source repositories available to a user by org
-}
viewSourceOrg : RepoSearchFilters -> Org -> Repositories -> Search msg -> EnableRepo msg -> EnableRepos msg -> Html msg
viewSourceOrg sourceSearchFilters org repos search enableRepo enableRepos =
    let
        ( repos_, filtered, content ) =
            if shouldSearch <| searchFilterLocal org sourceSearchFilters then
                -- Search and render repos using the global filter
                searchReposLocal org sourceSearchFilters repos enableRepo

            else
                -- Render repos normally
                ( repos, False, List.map (viewSourceRepo enableRepo) repos )
    in
    viewSourceOrgDetails sourceSearchFilters org repos_ filtered content search enableRepos


{-| viewSourceOrgDetails : renders the source repositories by org as an html details element
-}
viewSourceOrgDetails : RepoSearchFilters -> Org -> Repositories -> Bool -> List (Html msg) -> Search msg -> EnableRepos msg -> Html msg
viewSourceOrgDetails sourceSearchFilters org repos filtered content search enableRepos =
    div [ class "org" ]
        [ details [ class "details", class "repo-item" ] <|
            viewSourceOrgSummary sourceSearchFilters org repos filtered content search enableRepos
        ]


{-| viewSourceOrgSummary : renders the source repositories details summary
-}
viewSourceOrgSummary : RepoSearchFilters -> Org -> Repositories -> Bool -> List (Html msg) -> Search msg -> EnableRepos msg -> List (Html msg)
viewSourceOrgSummary sourceSearchFilters org repos filtered content search enableRepos =
    summary [ class "summary", Util.testAttribute <| "source-org-" ++ org ]
        [ div [ class "org-header" ]
            [ text org
            , viewRepoCount repos
            ]
        ]
        :: div [ class "source-actions" ]
            [ repoSearchBarLocal sourceSearchFilters org search
            , enableReposButton org repos filtered enableRepos
            ]
        :: content


{-| viewSourceRepo : renders single repo within a list of org repos

    viewSourceRepo uses model.SourceRepositories and buildAddRepoElement to determine the state of each specific 'Enable' button

-}
viewSourceRepo : EnableRepo msg -> Repository -> Html msg
viewSourceRepo enableRepo repo =
    div [ class "-item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div [] [ text repo.name ]
        , div []
            [ enableRepoButton repo enableRepo
            ]
        ]


{-| viewSearchedSourceRepo : renders single repo when searching across all repos
-}
viewSearchedSourceRepo : EnableRepo msg -> Repository -> Html msg
viewSearchedSourceRepo enableRepo repo =
    div [ class "-item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div []
            [ text <| repo.org ++ "/" ++ repo.name ]
        , div
            []
            [ enableRepoButton repo enableRepo
            ]
        ]


{-| viewRepoCount : renders the amount of repos available within an org
-}
viewRepoCount : List a -> Html msg
viewRepoCount repos =
    span [ class "repo-count", Util.testAttribute "source-repo-count" ] [ code [] [ text <| (String.fromInt <| List.length repos) ++ " repos" ] ]


{-| enableReposButton : takes List of repos and renders a button to enable them all at once, texts depends on user input filter
-}
enableReposButton : Org -> Repositories -> Bool -> EnableRepos msg -> Html msg
enableReposButton org repos filtered enableRepos =
    button [ class "-inverted", Util.testAttribute <| "add-org-" ++ org, onClick (enableRepos repos) ]
        [ text <|
            if filtered then
                "Enable Results"

            else
                "Enable All"
        ]


{-| enableRepoButton : builds action button for adding single repos
-}
enableRepoButton : Repository -> EnableRepo msg -> Html msg
enableRepoButton repo enableRepo =
    case repo.added of
        RemoteData.NotAsked ->
            button [ class "repo-enable-btn", class "-solid", onClick (enableRepo repo) ] [ text "Enable" ]

        RemoteData.Loading ->
            div [ class "repo-enable-btn", class "repo-enable--adding" ] [ span [ class "repo-enable--adding-text" ] [ text "Enabling" ], span [ class "loading-ellipsis" ] [] ]

        RemoteData.Failure _ ->
            div [ class "repo-enable-btn", class "repo-enable--failed", onClick (enableRepo repo) ] [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]

        RemoteData.Success activationStatus ->
            if activationStatus then
                div [ class "-added-container" ]
                    [ div [ class "repo-enable-btn", class "repo-enable--added" ] [ FeatherIcons.check |> FeatherIcons.toHtml [ attribute "role" "img" ], span [] [ text "Enabled" ] ]
                    , a [ class "-btn", class "-solid", class "-view", Routes.href <| Routes.RepositoryBuilds repo.org repo.name Nothing Nothing ] [ text "View" ]
                    ]

            else
                div [ class "repo-enable-btn", class "repo-enable--failed", onClick (enableRepo repo) ] [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]


{-| searchReposGlobal : takes source repositories and search filters and renders filtered repos
-}
searchReposGlobal : RepoSearchFilters -> SourceRepositories -> EnableRepo msg -> Html msg
searchReposGlobal filters repos enableRepo =
    let
        filteredRepos =
            repos
                |> Dict.toList
                |> Util.filterEmptyLists
                |> List.map (\( _, repos_ ) -> repos_)
                |> List.concat
                |> List.filter (\repo -> filterRepo filters Nothing <| repo.org ++ "/" ++ repo.name)
    in
    div [ class "filtered-repos" ] <|
        -- Render the found repositories
        if not <| List.isEmpty filteredRepos then
            filteredRepos |> List.map (\repo -> viewSearchedSourceRepo enableRepo repo)

        else
            -- No repos matched the search
            [ div [ class "-no-repos" ] [ text "No results" ] ]


{-| searchReposLocal : takes repo search filters, the org, and repos and renders a list of repos based on user-entered text
-}
searchReposLocal : Org -> RepoSearchFilters -> Repositories -> EnableRepo msg -> ( Repositories, Bool, List (Html msg) )
searchReposLocal org filters repos enableRepo =
    -- Filter the repos if the user typed more than 2 characters
    let
        filteredRepos =
            List.filter (\repo -> filterRepo filters (Just org) repo.name) repos
    in
    ( filteredRepos
    , True
    , if not <| List.isEmpty filteredRepos then
        List.map (viewSourceRepo enableRepo) filteredRepos

      else
        [ div [ class "-no-repos" ] [ text "No results" ] ]
    )
