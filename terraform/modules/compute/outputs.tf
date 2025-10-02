output "frontend_instance_id" {
  description = "ID of the frontend instance"
  value       = aws_instance.frontend.id
}

output "frontend_private_ip" {
  description = "Private IP address of the frontend instance"
  value       = aws_instance.frontend.private_ip
}

output "backend_instance_id" {
  description = "ID of the backend instance"
  value       = aws_instance.backend.id
}

output "backend_private_ip" {
  description = "Private IP address of the backend instance"
  value       = aws_instance.backend.private_ip
}

output "llm_instance_id" {
  description = "ID of the LLM service instance"
  value       = aws_instance.llm.id
}

output "llm_private_ip" {
  description = "Private IP address of the LLM service instance"
  value       = aws_instance.llm.private_ip
}

output "chromadb_instance_id" {
  description = "ID of the ChromaDB instance"
  value       = aws_instance.chromadb.id
}

output "chromadb_private_ip" {
  description = "Private IP address of the ChromaDB instance"
  value       = aws_instance.chromadb.private_ip
}

output "instance_ids" {
  description = "Map of all instance IDs"
  value = {
    frontend = aws_instance.frontend.id
    backend  = aws_instance.backend.id
    llm      = aws_instance.llm.id
    chromadb = aws_instance.chromadb.id
  }
}

output "private_ips" {
  description = "Map of all private IP addresses"
  value = {
    frontend = aws_instance.frontend.private_ip
    backend  = aws_instance.backend.private_ip
    llm      = aws_instance.llm.private_ip
    chromadb = aws_instance.chromadb.private_ip
  }
}
