package com.flowlogix.reproducers.grizzly;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

/** GET /echo/{value} returns the decoded path parameter verbatim. */
@Path("echo")
public class EchoResource {
    @GET
    @Path("{value}")
    @Produces(MediaType.TEXT_PLAIN)
    public String echo(@PathParam("value") String value) {
        return value;
    }
}
