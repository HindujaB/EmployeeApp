import ballerinax/mysql;
import ballerina/sql;
import ballerina/log;
import EmployeeApp.dbConnector;
import ballerina/io;

mysql:Client dbClient = connectDB();

public function main(string project) returns error? {
    foreach Employee emp in employees {
        validateQueryResult(check addEmployee(emp));
        check analyseProject(emp);
    }
    check addProjectTeam();
    string projectResult = retrieveProject(project);
    if (project != "") {
        check getEmployeeDetails(project, retrieveProject(project));
    }
}

function connectDB() returns mysql:Client {
    mysql:Client|sql:Error|() initializeClientResult = dbConnector:initializeClient();
    if (initializeClientResult is sql:Error || initializeClientResult is ()) {
        panic error("Query execution failed!\n", initializeClientResult);
    } else {
        return <mysql:Client>initializeClientResult;
    }
}

function retrieveProject(string project_name) returns string {
    sql:ParameterizedQuery query = `SELECT project_id FROM project
                                WHERE project_name = ${project_name}`;

    stream<record {}, error> resultStream = dbClient->query(query);
    record {|
        record {} value;
    |}|error? result = resultStream.next();
    if (result is error || result is ()) {
        log:printError("Next operation on the stream failed!", result, {});
    } else {
        return <string>result.value["project_id"];
    }
    return "";
}

function getEmployeeDetails(string project_name, string project_id) returns error? {
    sql:ParameterizedQuery query = `SELECT emp_id FROM project_team
                                WHERE project_id = ${project_id}`;
    stream<record {}, error> resultStream = dbClient->query(query);
    log:printInfo("Employees who worked in project : " + project_name);
    return resultStream.forEach(printEmployee);
}

function printEmployee(record {} employee) {
    int empID = <int>employee["emp_id"];
    sql:ParameterizedQuery query = `SELECT emp_id, name, position FROM employee
                                WHERE emp_id = ${empID}`;
    stream<record {}, error> resultStream = dbClient->query(query);
    error? result = resultStream.forEach(function(record {} employee) {
        io:println(employee);
    });
    if (result is error) {
        log:printError("Error occured when reading stream!");
    }
}
