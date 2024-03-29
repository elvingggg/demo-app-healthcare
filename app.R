library(shiny)
library(shinydashboard)
library(ggplot2)
library(dplyr)
library(plotly)
library(shinyWidgets)
library(shinyjs)
library(DT)
library(shinythemes)

# Define a function to fetch and process data from GitHub
fetch_healthcare_data <- function() {
  url <- "https://raw.githubusercontent.com/elvingggg/demo-app-healthcare/main/dummy_healthcare_data_malaysia.csv"
  data <- read.csv(url, stringsAsFactors = FALSE)
  data$DateReported <- as.Date(data$DateReported, format="%m/%d/%Y")
  return(data)
}

# Define your color scheme
colors <- list(
  darkGreen   = "#006400",
  orange      = "#FFA500",
  lightGreen  = "#90EE90",
  lightBlue   = "#ADD8E6",
  darkBlue    = "#00008B",
  teal        = "#008080",
  lightOrange = "#FFD580",
  darkOrange  = "#FF8C00",
  yellow      = "#FFFF00"
)

# Custom CSS for color scheme
custom_css <- sprintf("
.skin-blue .main-header .logo {
  background-color: %s; /* darkGreen */
  color: #fff;
}
.skin-blue .main-header .navbar {
  background-color: %s; /* orange */
}
.skin-blue .sidebar a {
  color: %s; /* lightGreen */
}
.skin-blue .sidebar .sidebar-menu > li.active > a {
  border-left-color: %s; /* lightBlue */
}
.skin-blue .box {
  border-top-color: %s; /* darkBlue */
}
.btn-primary {
  background-color: %s; /* teal */
  border-color: %s; /* darkOrange */
}
", colors$darkGreen, colors$orange, colors$lightGreen, colors$lightBlue,
colors$darkBlue, colors$teal, colors$darkOrange)

# UI definition
ui <- dashboardPage(
  dashboardHeader(title = "Malaysia Healthcare Analytics"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      uiOutput("stateInput"),
      uiOutput("conditionInput"),
      uiOutput("ageGroupInput"),
      uiOutput("startDateInput"),
      uiOutput("endDateInput")
    ),
    style = sprintf("background-color: %s; color: #fff;", colors$darkGreen)
  ),
  dashboardBody(
    tags$head(tags$style(HTML(custom_css))),
    useShinyjs(),
    tabItems(
      tabItem(tabName = "dashboard",
              fluidRow(
                valueBoxOutput("totalCases"),
                valueBoxOutput("averageCases")
              ),
              fluidRow(
                box(plotlyOutput("trendPlot"), status = "primary", solidHeader = TRUE, width = 12)
              ),
              fluidRow(
                box(DT::dataTableOutput("data_table"), status = "primary", solidHeader = TRUE, width = 12)
              )
      )
    ),
    theme = shinytheme("flatly")
  )
)

# Server logic
server <- function(input, output, session) {
  # Fetch data from GitHub
  healthcareData <- reactive(fetch_healthcare_data())
  
  # UI output logic for stateInput, conditionInput, ageGroupInput, startDateInput, endDateInput
  output$stateInput <- renderUI({
    selectInput("state", "State", choices = c("All", unique(healthcareData()$State)), selected = "All")
  })
  
  output$conditionInput <- renderUI({
    selectInput("condition", "Condition", choices = c("All", unique(healthcareData()$Condition)), selected = "All")
  })
  
  output$ageGroupInput <- renderUI({
    selectInput("ageGroup", "Age Group", choices = c("All", unique(healthcareData()$AgeGroup)), selected = "All")
  })
  
  output$startDateInput <- renderUI({
    dateInput("startDate", "Start Date", value = min(healthcareData()$DateReported, na.rm = TRUE))
  })
  
  output$endDateInput <- renderUI({
    dateInput("endDate", "End Date", value = max(healthcareData()$DateReported, na.rm = TRUE))
  })
  
  # Filter the data based on user-selected filters
  filteredData <- reactive({
    data <- healthcareData()
    if(input$state != "All") {
      data <- data %>% filter(State == input$state)
    }
    if(input$condition != "All") {
      data <- data %>% filter(Condition == input$condition)
    }
    if(input$ageGroup != "All") {
      data <- data %>% filter(AgeGroup == input$ageGroup)
    }
    if (!is.null(input$startDate) && !is.null(input$endDate)) {
      data <- data %>% filter(DateReported >= input$startDate & DateReported <= input$endDate)
    }
    data
  })
  
  # Display total cases and average cases
  output$totalCases <- renderValueBox({
    data <- filteredData()
    sum_cases <- sum(data$CasesReported, na.rm = TRUE)
    valueBox(
      formatC(sum_cases, format = "d", big.mark = ","),
      "Total Cases",
      icon = icon("hospital"),
      color = "red"
    )
  })
  
  output$averageCases <- renderValueBox({
    data <- filteredData()
    avg_cases <- ifelse(nrow(data) > 0 && sum(data$CasesReported, na.rm = TRUE) > 0,
                        round(mean(data$CasesReported, na.rm = TRUE), 2),
                        NA)
    valueBox(
      avg_cases,
      "Average Cases per Report",
      icon = icon("medkit"),
      color = "blue"
    )
  })
  
  # Render the trend plot
  output$trendPlot <- renderPlotly({
    req(filteredData())
    gg <- ggplot(filteredData(), aes(x = DateReported, y = CasesReported, group = 1)) +
      geom_line() +
      geom_point() +
      theme_minimal() +
      labs(title = paste("Trend of", ifelse(input$condition == "All", "All Conditions", input$condition),
                         "Cases in", ifelse(input$state == "All", "All States", input$state)),
           x = "Date",
           y = "Cases Reported")
    ggplotly(gg)
  })
  
  # Render the data table
  output$data_table <- DT::renderDataTable({
    req(healthcareData())
    DT::datatable(healthcareData(), options = list(pageLength = 10))
  })
}

# Run the Shiny app
shinyApp(ui, server)