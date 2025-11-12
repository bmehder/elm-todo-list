module Main exposing (main)

import Browser
import Html exposing (Html, button, div, form, input, label, li, p, span, text, ul)
import Html.Attributes exposing (checked, class, classList, placeholder, style, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as Decode exposing (Decoder)



-- DATA


type alias TodoId =
    Int


type alias Todo =
    { id : TodoId
    , description : String
    , completed : Bool
    }


type RemoteData a
    = Loading
    | Loaded a
    | Failed String


type TodoFilter
    = All
    | Active
    | Completed


type alias Model =
    { todos : RemoteData (List Todo)
    , draft : String
    , nextId : TodoId
    , filter : TodoFilter
    }


initialModel : Model
initialModel =
    { todos = Loading
    , draft = ""
    , nextId = 0
    , filter = All
    }



-- MESSAGES (event-style)


type Msg
    = InputChanged String
    | FormSubmitted
    | TodoToggled TodoId
    | TodoDeleted TodoId
    | FilterChanged TodoFilter
    | TodosFetched (Result Http.Error (List Todo))



-- UTILITY FUNCTIONS


reject : (a -> Bool) -> List a -> List a
reject predicate =
    List.filter (not << predicate)


todoDecoder : Decoder Todo
todoDecoder =
    Decode.map3 Todo
        (Decode.field "id" Decode.int)
        (Decode.field "todo" Decode.string)
        (Decode.field "completed" Decode.bool)


todosDecoder : Decoder (List Todo)
todosDecoder =
    Decode.field "todos" (Decode.list todoDecoder)


mapTodos : (List Todo -> List Todo) -> RemoteData (List Todo) -> RemoteData (List Todo)
mapTodos fn remoteData =
    case remoteData of
        Loaded todos ->
            Loaded (fn todos)

        _ ->
            remoteData



-- MODEL TRANSFORMATIONS


toggleTodo : TodoId -> Model -> Model
toggleTodo targetId model =
    { model
        | todos =
            mapTodos
                (List.map
                    (\todo ->
                        if todo.id == targetId then
                            { todo | completed = not todo.completed }

                        else
                            todo
                    )
                )
                model.todos
    }


deleteTodo : TodoId -> Model -> Model
deleteTodo targetId model =
    { model
        | todos =
            mapTodos
                (reject (.id >> (==) targetId))
                model.todos
    }


addTodo : Model -> Model
addTodo model =
    let
        trimmedText =
            String.trim model.draft
    in
    if trimmedText == "" then
        model

    else
        { model
            | todos =
                mapTodos
                    (\todos ->
                        { id = model.nextId, description = trimmedText, completed = False }
                            :: todos
                    )
                    model.todos
            , draft = ""
            , nextId = model.nextId + 1
        }


saveDraft : String -> Model -> Model
saveDraft newTodoText model =
    { model | draft = newTodoText }



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InputChanged newTodoText ->
            ( saveDraft newTodoText model, Cmd.none )

        FormSubmitted ->
            ( addTodo model, Cmd.none )

        TodoToggled todoId ->
            ( toggleTodo todoId model, Cmd.none )

        TodoDeleted todoId ->
            ( deleteTodo todoId model, Cmd.none )

        FilterChanged newFilter ->
            ( { model | filter = newFilter }, Cmd.none )

        TodosFetched result ->
            case result of
                Ok todos ->
                    let
                        maxId =
                            todos
                                |> List.map .id
                                |> List.maximum
                                |> Maybe.withDefault 0
                    in
                    ( { model
                        | todos = Loaded todos -- <-- wrap it
                        , nextId = maxId + 1
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( { model | todos = Failed "Unable to fetch todos." }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    case model.todos of
        Loading ->
            div []
                [ viewForm model
                , p [] [ text "Loading todos..." ]
                ]

        Failed err ->
            div []
                [ viewForm model
                , p [] [ text ("Error: " ++ err) ]
                ]

        Loaded todos ->
            let
                filteredTodos =
                    case model.filter of
                        All ->
                            todos

                        Active ->
                            reject .completed todos

                        Completed ->
                            List.filter .completed todos
            in
            div []
                [ viewForm model
                , if List.isEmpty filteredTodos then
                    p [] [ text "No todos yet! Add your first one above." ]

                  else
                    div []
                        [ ul [ class "p-0" ] (List.map viewTodo filteredTodos)
                        , viewFilters model.filter
                        ]
                , p [] [ viewSummary todos ]
                ]


viewForm : Model -> Html Msg
viewForm model =
    form [ onSubmit FormSubmitted, class "grid gap-0-2-5", style "grid-template-columns" "1fr auto" ]
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
    li [ class "flex justify-space-between align-items-center gap-0-5 pb-0-5" ]
        [ div []
            [ label [ class "flex align-items-center gap-0-5 text-align-left cursor-pointer" ]
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


viewFilters : TodoFilter -> Html Msg
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


viewSummary : List Todo -> Html Msg
viewSummary todos =
    let
        remaining =
            todos |> reject .completed |> List.length

        total =
            todos |> List.length

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
    Browser.element
        { init =
            \_ ->
                ( initialModel
                , Http.get
                    { url = "https://dummyjson.com/todos?limit=10"
                    , expect = Http.expectJson TodosFetched todosDecoder
                    }
                )
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }
