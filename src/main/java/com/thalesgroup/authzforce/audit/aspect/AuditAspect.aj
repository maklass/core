/**
 * Copyright (C) 2011-2013 Thales Services - ThereSIS - All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */
package com.thalesgroup.authzforce.audit.aspect;

import java.io.StringWriter;
import java.net.URI;
import java.text.DateFormat;
import java.text.SimpleDateFormat;

import javax.xml.bind.JAXBContext;
import javax.xml.bind.JAXBException;

import oasis.names.tc.xacml._3_0.core.schema.wd_17.Attribute;
import oasis.names.tc.xacml._3_0.core.schema.wd_17.AttributeValueType;
import oasis.names.tc.xacml._3_0.core.schema.wd_17.Policy;
import oasis.names.tc.xacml._3_0.core.schema.wd_17.Result;
import oasis.names.tc.xacml._3_0.core.schema.wd_17.Rule;

import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.AfterReturning;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.sun.xacml.BasicEvaluationCtx;
import com.sun.xacml.attr.DateTimeAttribute;
import com.sun.xacml.attr.xacmlv3.AttributeValue;
import com.sun.xacml.cond.xacmlv3.EvaluationResult;
import com.thalesgroup.authzforce.audit.AttributesResolved;
import com.thalesgroup.authzforce.audit.AuditLogs;
import com.thalesgroup.authzforce.audit.annotations.Audit;
import com.thalesgroup.authzforce.audit.schema.pdp.AuditLog;
import com.thalesgroup.authzforce.audit.schema.pdp.AuditedPolicy;
import com.thalesgroup.authzforce.audit.schema.pdp.AuditedResult;
import com.thalesgroup.authzforce.audit.schema.pdp.AuditedRule;
import com.thalesgroup.authzforce.xacml.schema.XACMLAttributeId;
import com.thalesgroup.authzforce.xacml.schema.XACMLDatatypes;

@Aspect
public class AuditAspect {

	private static final Logger LOGGER = LoggerFactory
			.getLogger(AuditAspect.class);
	private static final DateFormat dateFormat = new SimpleDateFormat(
			"dd-MM-yyyy HH:mm:ss.SSSSSSSSS");
	private static final DateFormat dateFormatWOoNano = new SimpleDateFormat(
			"dd-MM-yyyy HH:mm:ss");

	@Pointcut("execution (@com.thalesgroup.authzforce.audit.annotations * *.*(..))")
	public void searchAnnotation() {

	}

	@AfterReturning(value = "@annotation(annotation)", returning = "result")
	public void doAuditLog(Audit annotation, JoinPoint jp, Object result) {
		switch (annotation.type()) {
		case RULE:
			AuditLog audit = new AuditLog();
			AuditedRule auditedRule = new AuditedRule();
			auditedRule.setId(((Rule) jp.getTarget()).getRuleId());
			auditedRule.setResult(AuditedResult.fromValue(((Result) result)
					.getDecision().value()));
			for (Object arg : jp.getArgs()) {
				if (arg instanceof BasicEvaluationCtx) {
					audit.setDate(this.formatDate(((BasicEvaluationCtx) arg)
							.getCurrentDateTime()));
					audit.setRequest(((BasicEvaluationCtx) arg).getRequest());
					audit = this.setAttributes(audit, ((BasicEvaluationCtx) arg));
				}
			}

			audit.getRules().add(auditedRule);

			AuditLogs.getInstance().addAudit(audit);
			break;

		case POLICY:
			audit = new AuditLog();
			AuditedPolicy auditedPolicy = new AuditedPolicy();
			auditedPolicy.setId(((Policy) jp.getTarget()).getPolicyId());
			auditedPolicy.setRuleCombiningAlgorithm(((Policy) jp.getTarget())
					.getRuleCombiningAlgId());
			auditedPolicy.setResult(AuditedResult.fromValue(((Result) result)
					.getDecision().value()));
			for (Object arg : jp.getArgs()) {
				if (arg instanceof BasicEvaluationCtx) {
					audit.setDate(this.formatDate(((BasicEvaluationCtx) arg)
							.getCurrentDateTime()));
					audit.setRequest(((BasicEvaluationCtx) arg).getRequest());
					audit = this.setAttributes(audit, ((BasicEvaluationCtx) arg));;
				}
			}
			audit.getMatchedPolicies().add(auditedPolicy);
			AuditLogs.getInstance().addAudit(audit);
			break;

		case ATTRIBUTE:
			audit = new AuditLog();
			AttributesResolved attrResolved = new AttributesResolved();
			for (Object arg : jp.getArgs()) {
				if (arg instanceof BasicEvaluationCtx) {
					audit.setDate(this.formatDate(((BasicEvaluationCtx) arg)
							.getCurrentDateTime()));
					audit.setRequest(((BasicEvaluationCtx) arg).getRequest());
					audit = this.setAttributes(audit, ((BasicEvaluationCtx) arg));
				}
			}
			attrResolved.setAttributeValue(((EvaluationResult) result)
					.getAttributeValue());
			break;

		// Used to display and clean the audit log pool
		case DISPLAY:
			LOGGER.info(AuditLogs.getInstance().toString());
			break;
		default:
			System.err.println("Type unknown: " + annotation.type());
			;
		}
	}

	private AuditLog setAttributes(AuditLog audit,
			BasicEvaluationCtx basicEvaluationCtx) {
		audit.setSubjectId(String.valueOf(((BasicEvaluationCtx) basicEvaluationCtx)
				.getSubjectAttribute(
						URI.create(XACMLDatatypes.XACML_DATATYPE_STRING.value()),
						URI.create(XACMLAttributeId.XACML_SUBJECT_SUBJECT_ID
								.value()),
						URI.create(XACMLAttributeId.SUBJECT_CATEGORY.value()))
				.getAttributeValue().getContent().get(0)));

		AttributeValue resourceId = ((BasicEvaluationCtx) basicEvaluationCtx)
				.getResourceId();
		audit.setResourceId(String.valueOf(resourceId.getContent().get(0)));

		// FIXME: Set the ActionId attribute
		// audit.setActionId();
		
		return audit;
	}

	private String formatDate(DateTimeAttribute currentDateTime) {
		String date = dateFormatWOoNano.format(currentDateTime.getValue())
				+ "." + String.valueOf(currentDateTime.getNanoseconds());

		return date;
	}
}