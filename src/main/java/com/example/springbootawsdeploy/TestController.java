package com.example.springbootawsdeploy;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/demo")
public class TestController {

    @GetMapping("/data")
    public String getData() {
        System.out.println("Request received for /demo/data");
        return "This is my  AWS Certified DevOps Engineer - Professional Exam Project in Edureka! and this application deployed in AWS ECS";
    }

    @GetMapping("/message")
    public String getMessage() {
        System.out.println("Request received for /demo/message");
        return "Second message from AWS ECS";
    }
}
