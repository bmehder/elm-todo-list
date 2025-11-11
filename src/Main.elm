module Main exposing (main)

import Browser
import Html exposing (Html, button, div, form, input, label, li, p, span, text, ul)
import Html.Attributes exposing (checked, class, classList, placeholder, type_, style, value)
import Html.Events exposing (onClick, onInput, onSubmit)



-- DATA


type alias Todo =
    { id : Id
    , description : String
    , completed : Bool
    }


type alias Id =
    Int


type Filter
    = All
    | Active
    | Completed

    
type alias Model =
    { todos : List Todo
    , draft : String
    , nextId : Id
    , filter: Filter
    }


initialModel : Model
initialModel =
    { todos =
        [ { id = 1, description = "Learn Elm", completed = False }
        , { id = 2, description = "Write a Todo app", completed = False }
        , { id = 3, description = "Drink coffee", completed = True }
        ]
    , draft = ""
    , nextId = 4
    , filter = All
    }



-- MESSAGES (event-style)


type Msg
    = InputChanged String
    | FormSubmitted
    | TodoToggled Id
    | TodoDeleted Id
    | FilterChanged Filter


toggleTodo : Id -> Model -> Model
toggleTodo targetId model =
    { model
        | todos =
            List.map
                (\todo ->
                    if todo.id == targetId then
                        { todo | completed = not todo.completed }

                    else
                        todo
                )
                model.todos
    }


deleteTodo : Id -> Model -> Model
deleteTodo targetId model =
    { model
        | todos = List.filter (\{ id } -> id /= targetId) model.todos
    }


addTodo : Model -> Model
addTodo model =
    let
        trimmed =
            String.trim model.draft
    in
    if trimmed == "" then
        model

    else
        { model
            | todos =
                { id = model.nextId, description = trimmed, completed = False }
                    :: model.todos
            , draft = ""
            , nextId = model.nextId + 1
        }


saveDraft : String -> Model -> Model
saveDraft newTodo model =
    { model | draft = newTodo }



-- UPDATE


update : Msg -> Model -> Model
update msg model =
    case msg of
        InputChanged str ->
            saveDraft str model

        FormSubmitted ->
            addTodo model

        TodoToggled id ->
            toggleTodo id model

        TodoDeleted id ->
            deleteTodo id model

        FilterChanged newFilter ->
            { model | filter = newFilter }



-- VIEW


view : Model -> Html Msg
view model =
    let
        filteredTodos =
            case model.filter of
                All ->
                    model.todos

                Active ->
                    List.filter (\todo -> not todo.completed) model.todos

                Completed ->
                    List.filter .completed model.todos
    in
    div []
        [ viewForm model
        , ul [ class "p-0" ] (List.map viewTodo filteredTodos)
        , viewFilters model.filter
        , p [] [ viewSummary model ]
        ]


viewForm : Model -> Html Msg
viewForm model =
    form [ class "grid gap-0-2-5", style "grid-template-columns" "1fr auto", onSubmit FormSubmitted ]
        [ input
            [ type_ "text"
            , placeholder "What needs doing?"
            , value model.draft
            , onInput InputChanged
            ]
            []
        , button [ type_ "submit" ] [ text "Add" ]
        ]


viewTodo : Todo -> Html Msg
viewTodo todo =
    li [ class "flex justify-space-between align-items-center gap-0-5 line-height-3" ]
        [ div []
            [ label [ class "flex align-items-center gap-0-5 cursor-pointer" ]
                [ input
                    [ type_ "checkbox"
                    , checked todo.completed
                    , onClick (TodoToggled todo.id)
                    ]
                    []
                , span [ classList [ ( "line-through", todo.completed ) ] ]
                    [ text todo.description ]
                ]
            ]
        , button
            [ onClick (TodoDeleted todo.id) ]
            [ text "×" ]
        ]


viewFilters : Filter -> Html Msg
viewFilters currentFilter =
    let
        filterButton label filterType =
            button
                [ onClick (FilterChanged filterType)
                , classList [ ( "active", filterType == currentFilter ) ]
                ]
                [ text label ]
    in
    div [ class "grid gap-0-2-5", style "grid-template-columns" "repeat(3, 1fr)" ]
        [ filterButton "All" All
        , filterButton "Active" Active
        , filterButton "Completed" Completed
        ]


viewSummary : Model -> Html Msg
viewSummary model =
    let
        remaining =
            List.length (List.filter (not << .completed) model.todos)

        total =
            List.length model.todos

        label =
            String.fromInt remaining
                ++ " of "
                ++ String.fromInt total
                ++ (if total == 1 then
                        " todo"

                    else
                        " todos"
                   )
                ++ " remaining"
    in
    div [] [ text label ]



-- MAIN


main : Program () Model Msg
main =
    Browser.sandbox
        { init = initialModel
        , update = update
        , view = view
        }
