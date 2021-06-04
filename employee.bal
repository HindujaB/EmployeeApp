import ballerina/sql;
import ballerina/log;

type Employee record {|
    readonly int emp_id;
    string name;
    decimal salary;
    Position position;
    string[] projects;
|};

type Project record {|
    readonly string project_id;
    string project_name;
    Employee manager;
|};

enum Position {
    SE = "Software Engineer",
    PM = "Project Manager",
    TL = "Tech Lead"
}

const string PROJECT_ID_PREFIX = "project_";

configurable table<Employee> key(emp_id) & readonly employees = ?;

function addEmployee(Employee employee) returns int?|error {
    sql:ParameterizedQuery query = `INSERT INTO employee (emp_id, name, salary, position)
                                VALUES (${employee.emp_id},${employee.name}, ${employee.salary},${employee.position})`;
    sql:ExecutionResult result = check dbClient->execute(query);
    return result.affectedRowCount;
}

function analyseProject(Employee employee) returns error? {
    if (employee.position == PM) {
        int project_ID = 1;
        foreach string project_name in employee.projects {
            Project project = {
                project_id: PROJECT_ID_PREFIX + project_ID.toString(),
                project_name: project_name,
                manager: employee
            };
            validateQueryResult(check addProject(project));
            project_ID += 1;
        }

    }
}

function addProject(Project project) returns int?|error {
    sql:ParameterizedQuery query = `INSERT INTO project (project_id, project_name, project_manager_id) 
    VALUES (${project.project_id}, ${project.project_name}, ${project.manager.emp_id})`;
    sql:ExecutionResult result = check dbClient->execute(query);
    return result.affectedRowCount;
}

function addProjectTeam() returns error? {
    foreach Employee employee in employees {
        foreach string project in employee.projects {
            sql:ParameterizedQuery selectQuery = `SELECT project.project_id FROM project 
            WHERE (project.project_name = ${project})`;
            stream<record {}, error> resultStream = dbClient->query(selectQuery);

            record {|
                record {} value;
            |}|error? result = resultStream.next();
            if (result is record {|
                record {} value;
            |}) {
                anydata project_id = result.value["project_id"];
                sql:ParameterizedQuery query = `INSERT INTO project_team (project_id,emp_id) 
                VALUES (${<string>project_id}, ${employee.emp_id})`;
                sql:ExecutionResult queryResult = check dbClient->execute(query);
                validateQueryResult(queryResult.affectedRowCount);

            } else if (result is error) {
                log:printError("Next operation on the stream failed!", result, {});
            }

            check resultStream.close();
        }
    }
}

function validateQueryResult(int? rowCount) {
    if ((rowCount is int && <int>rowCount <= 0) || !(rowCount is int)) {
        log:printError("Failed to execute query");
    }
}
